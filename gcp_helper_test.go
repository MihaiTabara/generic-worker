package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"path/filepath"
	"testing"
	"time"

	"github.com/taskcluster/taskcluster-client-go/tcworkermanager"
)

type MockGCPProvisionedEnvironment struct {
}

func (m *MockGCPProvisionedEnvironment) Setup(t *testing.T) func() {
	teardown := setupEnvironment(t)
	workerType := testWorkerType()
	configureForGCP = true
	oldGCPMetadataBaseURL := GCPMetadataBaseURL
	GCPMetadataBaseURL = "http://localhost:13243/computeMetadata/v1"

	// Create custom *http.ServeMux rather than using http.DefaultServeMux, so
	// registered handler functions won't interfere with future tests that also
	// use http.DefaultServeMux.
	ec2MetadataHandler := http.NewServeMux()
	ec2MetadataHandler.HandleFunc("/", func(w http.ResponseWriter, req *http.Request) {
		switch req.URL.Path {

		// simulate GCP endpoints

		case "/computeMetadata/v1/instance/attributes/taskcluster":
			resp := map[string]interface{}{
				"workerPoolId": "test-provisioner/" + workerType,
				"providerId":   "test-provider",
				"workerGroup":  "workers",
				"rootURL":      "http://localhost:13243",
				"workerConfig": map[string]interface{}{
					"genericWorker": map[string]interface{}{
						"config": map[string]interface{}{
							"deploymentId": "12345",
						},
					},
				},
			}
			WriteJSON(t, w, resp)
		case "/computeMetadata/v1/instance/service-accounts/default/identity":
			fmt.Fprintf(w, "sekrit-token")
		case "/computeMetadata/v1/instance/image":
			fmt.Fprintf(w, "fancy-generic-worker-image")
		case "/computeMetadata/v1/instance/id":
			fmt.Fprintf(w, "some-id")
		case "/computeMetadata/v1/instance/machine-type":
			fmt.Fprintf(w, "n1-standard")
		case "/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip":
			fmt.Fprintf(w, "1.2.3.4")
		case "/computeMetadata/v1/instance/zone":
			fmt.Fprintf(w, "us-west1")
		case "/computeMetadata/v1/instance/hostname":
			fmt.Fprintf(w, "1-2-3-4-at.google.com")
		case "/computeMetadata/v1/instance/network-interfaces/0/ip":
			fmt.Fprintf(w, "10.10.10.10")

		case "/api/worker-manager/v1/worker/register":
			if req.Method != "POST" {
				w.WriteHeader(400)
				fmt.Fprintf(w, "Must register with POST")
			}
			d := json.NewDecoder(req.Body)
			d.DisallowUnknownFields()
			b := tcworkermanager.RegisterWorkerRequest{}
			err := d.Decode(&b)
			if err != nil {
				w.WriteHeader(400)
				fmt.Fprintf(w, "%v", err)
			}
			d = json.NewDecoder(bytes.NewBuffer(b.WorkerIdentityProof))
			d.DisallowUnknownFields()
			g := tcworkermanager.GoogleProviderType{}
			err = d.Decode(&g)
			if err != nil {
				w.WriteHeader(400)
				fmt.Fprintf(w, "%v", err)
			}
			if g.Token != "sekrit-token" {
				w.WriteHeader(400)
				fmt.Fprintf(w, "Got token %q but was expecting %q", g.Token, "sekrit-token")
			}
			resp := map[string]interface{}{
				"credentials": map[string]interface{}{
					"accessToken": "test-access-token",
					"certificate": "test-certificate",
					"clientId":    "test-client-id",
				},
			}
			WriteJSON(t, w, resp)

		default:
			w.WriteHeader(400)
			fmt.Fprintf(w, "Cannot serve URL %v", req.URL)
		}
	})
	s := &http.Server{
		Addr:           "localhost:13243",
		Handler:        ec2MetadataHandler,
		ReadTimeout:    10 * time.Second,
		WriteTimeout:   10 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}
	go func() {
		s.ListenAndServe()
		t.Log("HTTP server for mock Provisioner and GCP metadata endpoints stopped")
	}()
	var err error
	config, err = loadConfig(filepath.Join(testdataDir, t.Name(), "generic-worker.config"), false, true)
	if err != nil {
		t.Fatalf("Error: %v", err)
	}
	return func() {
		teardown()
		err := s.Shutdown(context.Background())
		if err != nil {
			t.Fatalf("Error shutting down http server: %v", err)
		}
		GCPMetadataBaseURL = oldGCPMetadataBaseURL
		configureForGCP = false
	}
}
