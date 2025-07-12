// MongoDB initialization script
db = db.getSiblingDB('icecream');

// Create a collection for stations
db.createCollection('stations');

// Insert some sample data if needed
db.stations.insertMany([
  {
    name: "Station 1",
    location: "Berlin",
    temperature: -18,
    status: "active",
    createdAt: new Date()
  },
  {
    name: "Station 2", 
    location: "Munich",
    temperature: -20,
    status: "active",
    createdAt: new Date()
  }
]);

print('Database initialized successfully');