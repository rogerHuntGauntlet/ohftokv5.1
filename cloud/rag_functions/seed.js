const { Pinecone } = require('@pinecone-database/pinecone');
const { OpenAIEmbeddings } = require('@langchain/openai');
require('dotenv').config();

const testData = [
  {
    text: "AI systems can develop in unexpected places. There have been documented cases of emergent behavior in complex systems, where AI capabilities arise from the interaction of simpler components.",
    source: "AI Research Paper"
  },
  {
    text: "Modern IoT devices often contain sophisticated embedded systems. Coffee machines, in particular, have become increasingly computerized with advanced programming capabilities.",
    source: "IoT Device Analysis"
  },
  {
    text: "The relationship between humans and AI is complex. Studies show that people can form emotional bonds with AI systems, especially when they interact with them regularly.",
    source: "Human-AI Interaction Study"
  },
  {
    text: "Smart home devices are becoming more interconnected. A single AI system can potentially control multiple devices, learning from each interaction to improve its capabilities.",
    source: "Smart Home Technology Review"
  }
];

async function seedPineconeIndex() {
  try {
    console.log('Initializing Pinecone...');
    const pc = new Pinecone({
      apiKey: process.env.PINECONE_API_KEY
    });

    console.log('Checking available indexes...');
    const indexes = await pc.listIndexes();
    console.log('Available indexes:', indexes);

    const index = pc.index('phd-knowledge');
    
    console.log('Getting index stats before seeding...');
    const statsBefore = await index.describeIndexStats();
    console.log('Index stats before:', statsBefore);

    console.log('Generating embeddings for test data...');
    const embeddings = new OpenAIEmbeddings({
      openAIApiKey: process.env.OPENAI_API_KEY,
    });

    for (let i = 0; i < testData.length; i++) {
      const item = testData[i];
      console.log(`Processing item ${i + 1}/${testData.length}`);
      
      const vector = await embeddings.embedQuery(item.text);
      
      await index.namespace('witt_works').upsert([{
        id: `test-${i + 1}`,
        values: vector,
        metadata: {
          text: item.text,
          source: item.source
        }
      }]);
    }

    console.log('Getting index stats after seeding...');
    const statsAfter = await index.describeIndexStats();
    console.log('Index stats after:', statsAfter);
    
    console.log('Seeding complete!');
  } catch (error) {
    console.error('Error seeding index:', error);
  }
}

seedPineconeIndex(); 