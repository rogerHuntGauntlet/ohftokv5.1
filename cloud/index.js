/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const functions = require('firebase-functions/v2');
const logger = require("firebase-functions/logger");
const admin = require('firebase-admin');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const { Pinecone } = require('@pinecone-database/pinecone');
const { OpenAIEmbeddings } = require('@langchain/openai');
const { OpenAI } = require('@langchain/openai');
const { PromptTemplate } = require('@langchain/core/prompts');
const { LLMChain } = require('langchain/chains');
const { Replicate } = require('replicate');
const axios = require('axios');
const { getStorage } = require('firebase-admin/storage');
const { FieldValue } = require('firebase-admin/firestore');
const { defineSecret } = require('firebase-functions/params');

admin.initializeApp();

// Import the RAG function
//const ragFunctions = require('./rag_functions');

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Export the generateMovieScenes function as an HTTP function
exports.generateMovieScenes = functions.https.onRequest({
  cors: true,
  maxInstances: 10,
  memory: '1GiB',
  cpu: 1,
  timeoutSeconds: 120
}, async (req, res) => {
  try {
    console.log('Received movie idea:', req.body.movieIdea);
    
    // Get API keys from environment variables
    const PINECONE_API_KEY = process.env.PINECONE_API_KEY;
    const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

    console.log('Environment variables loaded:', { 
      hasPinecone: !!PINECONE_API_KEY, 
      hasOpenAI: !!OPENAI_API_KEY,
      pineconeKeyLength: PINECONE_API_KEY ? PINECONE_API_KEY.length : 0,
      openaiKeyLength: OPENAI_API_KEY ? OPENAI_API_KEY.length : 0
    });

    if (!PINECONE_API_KEY || !OPENAI_API_KEY) {
      console.error('Missing required API keys');
      return res.status(500).json({ error: 'Server configuration error - Missing API keys' });
    }
    
    // Initialize Pinecone
    const pc = new Pinecone({
      apiKey: PINECONE_API_KEY
    });

    // List all indexes to verify connection
    console.log('Listing Pinecone indexes...');
    try {
      const indexes = await pc.listIndexes();
      console.log('Available indexes:', indexes);
    } catch (error) {
      console.error('Error listing Pinecone indexes:', error);
      // Continue anyway as we know the index exists
    }

    const { movieIdea } = req.body;
    if (!movieIdea) {
      return res.status(400).json({ error: 'Movie idea is required' });
    }

    console.log('Generating embeddings...');
    // Get embeddings for the movie idea
    const embeddings = new OpenAIEmbeddings({
      openAIApiKey: OPENAI_API_KEY,
    });
    
    const queryEmbedding = await embeddings.embedQuery(movieIdea);

    console.log('Querying Pinecone...');
    // Query Pinecone for relevant context
    const index = pc.index('phd-knowledge');

    // Get index stats to verify content
    try {
      const stats = await index.describeIndexStats();
      console.log('Index stats:', stats);
    } catch (error) {
      console.error('Error getting index stats:', error);
      // Continue anyway
    }
    
    console.log('Attempting query with:', {
      vector: queryEmbedding.slice(0, 5), // Log just first 5 dimensions for brevity
      topK: 5,
      includeMetadata: true
    });

    const queryResponse = await index.namespace('witt_works').query({
      vector: queryEmbedding,
      topK: 5,
      includeMetadata: true
    });

    // Build context from similar entries with better error handling
    const contextParts = [];
    if (queryResponse.matches && queryResponse.matches.length > 0) {
      for (const match of queryResponse.matches) {
        console.log('Processing match score:', match.score);
        
        if (!match.metadata) {
          console.log('Match missing metadata:', match);
          continue;
        }

        if (match.metadata.text) {
          contextParts.push(`- ${match.metadata.text}`);
          if (match.metadata.source) {
            contextParts.push(`  Source: ${match.metadata.source}`);
          }
          contextParts.push('');
        } else {
          console.log('Match metadata missing text:', match.metadata);
        }
      }
    } else {
      console.log('No matches found in Pinecone response');
    }

    const context = contextParts.join('\n');
    console.log('Context built:', context || 'No context available');

    console.log('Generating scenes with OpenAI...');
    // Generate scenes using OpenAI
    const prompt = PromptTemplate.fromTemplate(`
      You are a creative movie scene generator. Using the provided movie idea and the knowledge from our database,
      generate a list of compelling scenes that would make an engaging short-form video.
      Each scene should be concise but descriptive, and incorporate relevant elements from the provided knowledge.

      Movie Idea: {movieIdea}
      
      Knowledge Context (use this to enhance the scenes with relevant details):
      {context}
      
      Generate 5-7 scenes that would make this movie idea work well as a short-form video.
      Each scene should:
      1. Be visually descriptive and engaging
      2. Incorporate elements from the knowledge context if relevant
      3. Follow a clear narrative arc
      4. Be suitable for short-form video format
      
      Format each scene as a numbered list.
    `);

    const model = new OpenAI({
      openAIApiKey: OPENAI_API_KEY,
      temperature: 0.7,
      modelName: 'gpt-4',
    });

    const chain = new LLMChain({
      prompt: prompt,
      llm: model,
    });

    const response = await chain.call({
      movieIdea: movieIdea,
      context: context,
    });

    console.log('Raw response:', response);

    // Parse the response into a structured list of scenes
    const scenes = response.text
      .split(/\d+\.\s+/)  // Split by numbers followed by a period and whitespace
      .filter(text => text.trim())  // Remove empty entries
      .map((sceneText, index) => {
        // Extract scene title and description if present
        const match = sceneText.match(/^(Scene \w+):\s*(.*)/s);
        const title = match ? match[1] : `Scene ${index + 1}`;
        const description = match ? match[2].trim() : sceneText.trim();
        
        return {
          id: index + 1,
          title: title,
          text: description,
          duration: 15, // Default duration in seconds
          type: 'scene',
          status: 'pending'
        };
      });

    console.log('Final scenes:', scenes);
    res.status(200).json({ 
      scenes,
      metadata: {
        totalScenes: scenes.length,
        movieIdea: movieIdea,
        generatedAt: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('Error details:', {
      message: error.message,
      stack: error.stack,
      name: error.name
    });
    res.status(500).json({ 
      error: 'Failed to generate movie scenes. Please try again.',
      details: error.message
    });
  }
}); 

// Export the onUserCreated function with proper configuration


/**
 exports.generateMovieScenes = functions.https.onRequest({
  cors: true,
  maxInstances: 10,
  memory: '1GiB',
  cpu: 1,
  timeoutSeconds: 120
}, async (req, res) => {
 */

exports.onUserCreated = functions.firestore.onDocumentCreated({
  document: 'users/{userId}',
  memory: '256MiB',
  cpu: 0.5,
  maxInstances: 10,
  timeoutSeconds: 30
}, async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
        return;
    }

    const userData = snapshot.data();
    const userId = event.params.userId;
    
    logger.info("Processing new user profile:", userData.email);

    try {
        // Update the document with additional fields
        await snapshot.ref.update({
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastLogin: admin.firestore.FieldValue.serverTimestamp(),
            hasCompletedOnboarding: false,
            profileCompletion: 0,
            tokens: 0,
            emailVerified: false,
            role: 'user'
        });
        
        logger.info("Successfully processed profile for user:", userData.email);
    } catch (error) {
        logger.error("Error processing user profile:", error);
        throw error;
    }
});

// Define secrets
const REPLICATE_API_TOKEN = defineSecret('REPLICATE_API_TOKEN');

// Constants for progress tracking
const PROGRESS_STAGES = {
  ANALYZING: { progress: 0.1, message: 'Analyzing scene' },
  GENERATING: { progress: 0.3, message: 'Generating video frames' },
  PROCESSING: { progress: 0.6, message: 'Processing video' },
  DOWNLOADING: { progress: 0.8, message: 'Downloading video' },
  UPLOADING: { progress: 0.9, message: 'Uploading to storage' },
  COMPLETED: { progress: 1.0, message: 'Video ready!' }
};

// Helper function to get server timestamp
const getServerTimestamp = () => FieldValue.serverTimestamp();

// Helper function to generate standard video metadata
const generateVideoMetadata = (videoId, jobData, sourceType = 'ai') => ({
  contentType: 'video/mp4',
  metadata: {
    videoId,
    movieId: jobData.movieId,
    sceneId: jobData.sceneId,
    userId: jobData.userId,
    uploadedAt: new Date().toISOString(),
    sourceType,
    ...(sourceType === 'ai' && {
      predictionId: jobData.predictionId,
      description: jobData.sceneText
    })
  }
});

// Helper function to update scene document
const updateSceneWithVideo = async (movieId, sceneId, videoUrl, videoId, sourceType = 'ai') => {
  const sceneRef = admin.firestore()
    .collection('movies')
    .doc(movieId)
    .collection('scenes')
    .doc(sceneId);

  await sceneRef.update({
    videoUrl,
    videoId,
    status: 'completed',
    videoType: sourceType,
    updatedAt: getServerTimestamp()
  });
};

// Generate video for a scene


exports.generateSingleScene = functions.https.onRequest({
  cors: true,
  maxInstances: 10,
  memory: '1GiB',
  cpu: 1,
  timeoutSeconds: 250
}, async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    console.log('Received generate request:', JSON.stringify(req.body, null, 2));
    
    const { scene, userId } = req.body;
    if (!scene || !scene.text || !userId) {
      return res.status(400).json({ error: 'Scene text and userId are required' });
    }

    const replicateToken = process.env.REPLICATE_API_TOKEN;
    if (!replicateToken) {
      console.error('Missing Replicate API token');
      return res.status(500).json({ error: 'Server configuration error - Missing Replicate API token' });
    }

    // Create prediction using Replicate API
    console.log('Creating prediction with text:', scene.text);
    const predictionResponse = await axios.post('https://api.replicate.com/v1/predictions', {
      version: "luma/ray",
      input: { prompt: scene.text }
    }, {
      headers: {
        'Authorization': `Bearer ${replicateToken}`,
        'Content-Type': 'application/json'
      }
    });

    const predictionId = predictionResponse.data.id;
    console.log('Prediction created:', predictionId);

    // Poll for completion
    let isComplete = false;
    let videoUrl = '';
    let attempts = 0;
    const maxAttempts = 60; // 2 minutes with 2-second intervals

    while (!isComplete && attempts < maxAttempts) {
      await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds between checks
      
      const statusResponse = await axios.get(`https://api.replicate.com/v1/predictions/${predictionId}`, {
        headers: { 'Authorization': `Bearer ${replicateToken}` }
      });

      console.log('Replicate status:', statusResponse.data.status);

      if (statusResponse.data.status === 'succeeded') {
        isComplete = true;
        videoUrl = statusResponse.data.output;
      } else if (statusResponse.data.status === 'failed') {
        throw new Error(statusResponse.data.error || 'Video generation failed');
      }

      attempts++;
    }

    if (!isComplete) {
      throw new Error('Video generation timed out');
    }

    res.status(200).json({
      success: true,
      videoUrl: videoUrl,
      predictionId: predictionId
    });

  } catch (error) {
    console.error('Error generating video:', error.response?.data || error);
    res.status(500).json({
      error: 'Failed to generate video',
      details: error.response?.data || error.message
    });
  }
});

// Check generation status
exports.getGenerationStatus = functions.https.onRequest({
  cors: true,
  maxInstances: 10,
  memory: '1GiB',
  cpu: 1,
  timeoutSeconds: 120
}, async (req, res) => {
  try {
    const { jobId } = req.body;
    if (!jobId) {
      return res.status(400).json({ error: 'jobId is required' });
    }

    // Get job data from Firestore
    const jobRef = admin.firestore().collection('videoJobs').doc(jobId);
    const jobDoc = await jobRef.get();
    
    if (!jobDoc.exists) {
      return res.status(404).json({ error: 'Job not found' });
    }

    const jobData = jobDoc.data();
    if (jobData.status === 'completed' && jobData.videoUrl) {
      return res.status(200).json({
        status: 'completed',
        progress: PROGRESS_STAGES.COMPLETED.progress,
        videoUrl: jobData.videoUrl,
        videoId: jobData.videoId
      });
    }

    // Check Replicate status
    const replicateToken = process.env.REPLICATE_API_TOKEN;
    const prediction = await axios.get(`https://api.replicate.com/v1/predictions/${jobId}`, {
      headers: { 'Authorization': `Bearer ${replicateToken}` }
    });

    console.log('Replicate status:', prediction.data.status);

    switch (prediction.data.status) {
      case 'starting':
        await jobRef.update({
          status: 'analyzing',
          progress: PROGRESS_STAGES.ANALYZING.progress,
          message: PROGRESS_STAGES.ANALYZING.message,
          updatedAt: getServerTimestamp()
        });
        break;

      case 'processing':
        // Only update if we're not in a later stage
        if (!['downloading', 'uploading', 'completed'].includes(jobData.status)) {
          await jobRef.update({
            status: 'generating',
            progress: PROGRESS_STAGES.GENERATING.progress,
            message: PROGRESS_STAGES.GENERATING.message,
            updatedAt: getServerTimestamp()
          });
        }
        break;

      case 'succeeded':
        if (!jobData.videoUrl) {
          console.log('Processing completed video...');
          
          try {
            // Update status to downloading
            await jobRef.update({
              status: 'downloading',
              progress: PROGRESS_STAGES.DOWNLOADING.progress,
              message: PROGRESS_STAGES.DOWNLOADING.message,
              updatedAt: getServerTimestamp()
            });

            // Download video from Replicate
            const replicateVideoUrl = prediction.data.output;
            const videoResponse = await axios.get(replicateVideoUrl, {
              responseType: 'arraybuffer',
              headers: { 'Authorization': `Bearer ${replicateToken}` }
            });

            // Update status to uploading
            await jobRef.update({
              status: 'uploading',
              progress: PROGRESS_STAGES.UPLOADING.progress,
              message: PROGRESS_STAGES.UPLOADING.message,
              updatedAt: getServerTimestamp()
            });

            // Generate videoId and prepare for storage
            const videoId = admin.firestore().collection('videos').doc().id;
            const bucket = getStorage().bucket();
            const file = bucket.file(`${videoId}.mp4`);

            // Upload to Firebase Storage
            await file.save(videoResponse.data, {
              metadata: generateVideoMetadata(videoId, jobData)
            });

            // Get download URL
            const [videoUrl] = await file.getDownloadURL();

            // Update job document with completion
            await jobRef.update({
              status: 'completed',
              progress: PROGRESS_STAGES.COMPLETED.progress,
              message: PROGRESS_STAGES.COMPLETED.message,
              videoUrl,
              videoId,
              completedAt: getServerTimestamp(),
              updatedAt: getServerTimestamp()
            });

            // Update scene document
            await updateSceneWithVideo(
              jobData.movieId,
              jobData.sceneId,
              videoUrl,
              videoId
            );

            return res.status(200).json({
              status: 'completed',
              progress: PROGRESS_STAGES.COMPLETED.progress,
              videoUrl,
              videoId
            });
          } catch (error) {
            console.error('Error processing video:', error);
            await jobRef.update({
              status: 'failed',
              error: error.message || 'Error processing video',
              updatedAt: getServerTimestamp()
            });
            throw error;
          }
        }
        break;

      case 'failed':
        await jobRef.update({
          status: 'failed',
          error: prediction.data.error || 'Video generation failed',
          updatedAt: getServerTimestamp()
        });
        return res.status(500).json({
          status: 'failed',
          error: prediction.data.error || 'Video generation failed'
        });

      case 'canceled':
        await jobRef.update({
          status: 'failed',
          error: 'Video generation was canceled',
          updatedAt: getServerTimestamp()
        });
        return res.status(500).json({
          status: 'failed',
          error: 'Video generation was canceled'
        });
    }

    // Return current status
    res.status(200).json({
      status: jobData.status,
      progress: jobData.progress,
      message: jobData.message
    });

  } catch (error) {
    console.error('Error checking generation status:', error);
    res.status(500).json({
      error: 'Failed to check video generation status',
      details: error.message
    });
  }
});

// Generate additional scenes for an existing movie
exports.generateAdditionalScenes = functions.https.onRequest({
  cors: true,
  maxInstances: 10,
  memory: '1GiB',
  cpu: 1,
  timeoutSeconds: 120
}, async (req, res) => {
  try {
    console.log('Received request for additional scenes:', req.body);
    
    // Get API keys from environment variables
    const PINECONE_API_KEY = process.env.PINECONE_API_KEY;
    const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

    if (!PINECONE_API_KEY || !OPENAI_API_KEY) {
      console.error('Missing required API keys');
      return res.status(500).json({ error: 'Server configuration error - Missing API keys' });
    }

    const { movieId, existingScenes, continuationIdea, numNewScenes } = req.body;
    if (!movieId || !existingScenes || !continuationIdea || !numNewScenes) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    // Initialize OpenAI
    const model = new OpenAI({
      openAIApiKey: OPENAI_API_KEY,
      temperature: 0.7,
      modelName: 'gpt-4',
    });

    // First, analyze the existing scenes and new direction
    console.log('Analyzing existing scenes and new direction...');
    const analysisPrompt = PromptTemplate.fromTemplate(`
      You are a creative movie analyst and scene writer. Analyze the existing scenes and the new direction for this movie.
      
      Existing Scenes:
      {existingScenes}
      
      New Direction:
      {continuationIdea}
      
      Provide a comprehensive analysis of:
      1. The current narrative arc and themes
      2. The established style and tone
      3. Key characters and their development
      4. Visual and cinematic elements
      5. Genre elements present
      
      Format your analysis as a structured summary that will be used to inform the creation of new scenes.
    `);

    const analysisChain = new LLMChain({
      prompt: analysisPrompt,
      llm: model,
    });

    const analysis = await analysisChain.call({
      existingScenes: existingScenes.map(scene => `Scene ${scene.id}: ${scene.text}`).join('\n'),
      continuationIdea: continuationIdea,
    });

    console.log('Movie analysis complete:', analysis);

    // Now generate the new scenes
    console.log('Generating new scenes...');
    const newScenesPrompt = PromptTemplate.fromTemplate(`
      You are a creative movie scene generator. Using the provided analysis and new direction,
      generate additional scenes that continue the movie's narrative while maintaining consistency
      with the established style and themes.

      Movie Analysis:
      {analysis}
      
      New Direction:
      {continuationIdea}
      
      Generate EXACTLY {numNewScenes} new scenes that:
      1. Continue naturally from the existing scenes
      2. Maintain consistency with the established style and tone
      3. Further develop the narrative and themes
      4. Are visually descriptive and engaging
      5. Are suitable for short-form video format
      
      IMPORTANT: 
      - You MUST generate exactly {numNewScenes} scenes, no more and no less.
      - Format each scene exactly as shown in the example below, maintaining the exact format.
      - Start scene numbers from {startingSceneNum}.
      
      Example format:
      SCENE_START
      Number: {startingSceneNum}
      Description: [Your scene description here]
      SCENE_END

      Repeat this format for each scene, incrementing the Number each time.
    `);

    const newScenesChain = new LLMChain({
      prompt: newScenesPrompt,
      llm: model,
    });

    const startingSceneNum = existingScenes.length + 1;

    const newScenesResponse = await newScenesChain.call({
      analysis: analysis.text,
      continuationIdea: continuationIdea,
      numNewScenes: numNewScenes,
      startingSceneNum: startingSceneNum,
    });

    console.log('Raw new scenes response:', newScenesResponse);

    // Parse the response into a structured list of scenes using a more robust method
    const scenes = newScenesResponse.text
      .split('SCENE_START')
      .filter(text => text.trim())
      .map(sceneBlock => {
        const numberMatch = sceneBlock.match(/Number:\s*(\d+)/);
        const descriptionMatch = sceneBlock.match(/Description:\s*([\s\S]*?)(?:SCENE_END|$)/);
        
        if (!numberMatch || !descriptionMatch) {
          console.error('Failed to parse scene block:', sceneBlock);
          throw new Error('Scene generation format was incorrect');
        }

        const sceneNumber = parseInt(numberMatch[1]);
        const description = descriptionMatch[1].trim();

        return {
          id: sceneNumber,
          title: `Scene ${sceneNumber}`,
          text: description,
          duration: 15,
          type: 'scene',
          status: 'pending',
          movieId: movieId,
        };
      });

    // Verify we got the correct number of scenes
    if (scenes.length !== numNewScenes) {
      console.error(`Generated ${scenes.length} scenes but expected ${numNewScenes}`);
      console.error('Generated scenes:', scenes);
      console.error('Raw response:', newScenesResponse.text);
      throw new Error(`Failed to generate the requested number of scenes (got ${scenes.length}, expected ${numNewScenes})`);
    }

    // Verify scene numbers are sequential
    const expectedNumbers = Array.from(
      { length: numNewScenes }, 
      (_, i) => startingSceneNum + i
    );
    
    const hasCorrectNumbers = scenes.every((scene, index) => 
      scene.id === expectedNumbers[index]
    );

    if (!hasCorrectNumbers) {
      console.error('Scene numbers are not sequential:', scenes.map(s => s.id));
      throw new Error('Generated scenes have incorrect numbering');
    }

    // Update the movie document with the new scenes
    const movieRef = admin.firestore().collection('movies').doc(movieId);
    const batch = admin.firestore().batch();

    for (const scene of scenes) {
      const sceneRef = movieRef.collection('scenes').doc();
      batch.set(sceneRef, {
        ...scene,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    console.log('Final new scenes:', scenes);
    res.status(200).json({ 
      scenes: scenes,
      metadata: {
        totalNewScenes: scenes.length,
        continuationIdea: continuationIdea,
        generatedAt: new Date().toISOString(),
        movieId: movieId
      }
    });
  } catch (error) {
    console.error('Error generating additional scenes:', {
      message: error.message,
      stack: error.stack,
      name: error.name
    });
    res.status(500).json({ 
      error: 'Failed to generate additional scenes. Please try again.',
      details: error.message
    });
  }
});
