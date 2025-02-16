# OHFtok

A Flutter application that generates creative movie scenes using AI.

## Features

- Speech-to-text movie idea input
- AI-powered scene generation using GPT-4
- Scene editing and management
- Firebase integration for data persistence
- Real-time updates

## Setup

1. Clone the repository
```bash
git clone https://github.com/yourusername/ohftokv5.git
cd ohftokv5
```

2. Install dependencies
```bash
# Install Flutter dependencies
flutter pub get

# Install Cloud Functions dependencies
cd cloud
npm install
```

3. Set up environment variables
```bash
# Copy the example environment file
cp cloud/.env.example cloud/.env

# Edit .env with your API keys
# Required APIs:
# - OpenAI
# - Pinecone
# - Replicate
```

4. Set up Firebase
- Create a new Firebase project
- Enable Firestore
- Set up Firebase Authentication
- Deploy Firebase Functions

5. Run the app
```bash
flutter run
```

## Project Structure

- `/lib` - Flutter application code
- `/cloud` - Firebase Cloud Functions
  - `functions.js` - Main functions code
  - `server.js` - Local development server

## Development

To run the local development server:
```bash
cd cloud
npm run serve
```

To deploy Firebase Functions:
```bash
cd cloud
npm run deploy
```

## Environment Variables

Required environment variables in `cloud/.env`:
- `OPENAI_API_KEY` - OpenAI API key for GPT-4
- `PINECONE_API_KEY` - Pinecone API key for vector database
- `REPLICATE_API_TOKEN` - Replicate API token for additional AI models

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request
