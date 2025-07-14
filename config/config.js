module.exports = {
    server: {
        port: process.env.PORT || 3000,
        hostname: process.env.HOSTNAME || '0.0.0.0',
    },
    database: {
      url: 'mongodb://admin:password@mongodb-service:27017',
      name: 'icecream'
    }
  };
