// Simple MongoDB initialization
db = db.getSiblingDB('icecream');
db.createCollection('stations');
print('Database initialized');