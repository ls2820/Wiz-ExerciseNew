package main

import (
	"context"
	"encoding/json" // Added this to handle JSON properly
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type Task struct {
	Title string `json:"title" bson:"title"`
}

var client *mongo.Client

func main() {
	mongoURI := os.Getenv("MONGODB_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017"
	}

	fmt.Printf("Connecting to MongoDB at: %s\n", mongoURI)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	
	
	var err error
	client, err = mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))

	if err != nil {
		fmt.Printf("Failed to connect to MongoDB: %v\n", err)
	} else {
		fmt.Println("Successfully connected to MongoDB!")
	}

	// Route Handlers
	http.HandleFunc("/api/tasks", taskHandler)
	
	fs := http.FileServer(http.Dir("assets"))
	http.Handle("/assets/", http.StripPrefix("/assets/", fs))

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		http.ServeFile(w, r, "index.html")
	})

	fmt.Println("Server starting on :8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func taskHandler(w http.ResponseWriter, r *http.Request) {
	// Guard against nil client
	if client == nil {
		http.Error(w, "Database not connected", 500)
		return
	}

	collection := client.Database("taskdb").Collection("tasks")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if r.Method == "GET" {
		cursor, err := collection.Find(ctx, map[string]interface{}{})
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		var tasks []Task
		if err = cursor.All(ctx, &tasks); err != nil {
			tasks = []Task{} // Ensure it's an empty list, not null
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(tasks)

	} else if r.Method == "POST" {
		var newTask Task
		if err := json.NewDecoder(r.Body).Decode(&newTask); err != nil {
			http.Error(w, err.Error(), 400)
			return
		}

		_, err := collection.InsertOne(ctx, newTask)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		w.WriteHeader(http.StatusCreated)
		fmt.Fprintf(w, `{"message": "Task saved successfully"}`)
	}
}