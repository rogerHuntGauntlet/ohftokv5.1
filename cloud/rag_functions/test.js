const http = require('http');

const data = JSON.stringify({
  movieIdea: "A story about a programmer who discovers AI in their coffee machine"
});

const options = {
  hostname: 'localhost',
  port: 5001,
  path: '/generateMovieScenes',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  },
  timeout: 30000 // 30 second timeout
};

const makeRequest = () => {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let responseData = '';

      res.on('data', (chunk) => {
        responseData += chunk;
      });

      res.on('end', () => {
        console.log('Status:', res.statusCode);
        try {
          const parsedData = JSON.parse(responseData);
          console.log('Response:', JSON.stringify(parsedData, null, 2));
          resolve(parsedData);
        } catch (e) {
          console.log('Raw response:', responseData);
          reject(e);
        }
      });
    });

    req.on('error', (error) => {
      console.error('Request error:', error);
      reject(error);
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timed out'));
    });

    req.write(data);
    req.end();
  });
};

// Make the request
makeRequest()
  .catch(error => {
    console.error('Failed to complete request:', error);
    process.exit(1);
  }); 