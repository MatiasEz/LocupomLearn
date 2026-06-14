const http = require("http");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");

const PORT = Number(process.env.PORT || 8787);
const ROOT_DIR = __dirname;
const DATA_DIR = path.join(ROOT_DIR, "data");
const PDF_DIR = path.join(ROOT_DIR, "pdfs");
const MORNING_BRIEF_CONTENT_PATH = path.join(DATA_DIR, "morning-brief-content.json");
const PROGRESS_FILE = process.env.LOCUPOM_PROGRESS_FILE
  || path.join(process.env.LOCUPOM_PROGRESS_DIR || os.tmpdir(), "locupom-progress.json");

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type,Authorization",
  "Access-Control-Max-Age": "86400"
};

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function loadJSON(filePath, fallback) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return fallback;
  }
}

let progressCache = null;

function emptyProgressStore() {
  return {
    version: 1,
    updatedAt: null,
    learners: {}
  };
}

function loadProgressStore() {
  if (progressCache) return progressCache;
  const loaded = loadJSON(PROGRESS_FILE, emptyProgressStore());
  progressCache = {
    version: loaded.version || 1,
    updatedAt: loaded.updatedAt || null,
    learners: loaded.learners && typeof loaded.learners === "object" ? loaded.learners : {}
  };
  return progressCache;
}

function saveProgressStore(store) {
  store.updatedAt = new Date().toISOString();
  const directory = path.dirname(PROGRESS_FILE);
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(store, null, 2));
}

function normalizeLearnerId(value) {
  const learnerId = String(value || "").trim();
  if (!learnerId) return null;
  if (learnerId.length > 120) return null;
  if (!/^[a-zA-Z0-9._:@-]+$/.test(learnerId)) return null;
  return learnerId;
}

function requireLearnerId(value) {
  const learnerId = normalizeLearnerId(value);
  if (!learnerId) {
    throw httpError(400, "learnerId is required and may only contain letters, numbers, dots, underscores, colons, @ and hyphens.");
  }
  return learnerId;
}

function learnerProgress(store, learnerId) {
  store.learners[learnerId] ||= {
    completed: {},
    createdAt: new Date().toISOString(),
    updatedAt: null
  };
  store.learners[learnerId].completed ||= {};
  return store.learners[learnerId];
}

function normalizeProgressKind(value) {
  const key = String(value || "item").trim().toLowerCase().replace(/[^a-z]/g, "");
  const aliases = {
    reading: "reading",
    readings: "reading",
    exercise: "exercise",
    exercises: "exercise",
    speaking: "speaking",
    speakingprompt: "speaking",
    speakingprompts: "speaking",
    vocabulary: "vocabulary",
    vocab: "vocabulary",
    word: "vocabulary",
    topic: "topic",
    topics: "topic",
    roadmap: "topic",
    item: "item"
  };
  return aliases[key] || "item";
}

function completionKey(kind, itemId) {
  return `${normalizeProgressKind(kind)}:${String(itemId || "").trim()}`;
}

function parseCompletionIdentifier(value, fallbackKind = "item") {
  const raw = String(value || "").trim();
  if (!raw) return null;
  const match = raw.match(/^([a-zA-Z][a-zA-Z_.-]*):(.*)$/);
  if (match && match[2]) {
    return {
      kind: normalizeProgressKind(match[1]),
      itemId: match[2].trim()
    };
  }
  return {
    kind: normalizeProgressKind(fallbackKind),
    itemId: raw
  };
}

function normalizeCompletionPayload(payload) {
  const source = payload?.item && typeof payload.item === "object" ? payload.item : payload || {};
  const parsed = parseCompletionIdentifier(
    source.key || source.completionKey || source.progressKey || source.id,
    source.kind || source.type || "item"
  );
  const rawItemId = String(source.itemId || source.contentId || parsed?.itemId || "").trim();
  const parsedItemId = parseCompletionIdentifier(rawItemId, source.kind || source.type || parsed?.kind || "item");
  const kind = normalizeProgressKind(source.kind || source.type || parsed?.kind || parsedItemId?.kind);
  const itemId = String(parsedItemId?.itemId || rawItemId).trim();

  if (!itemId) {
    throw httpError(400, "itemId is required. You can also pass id as 'kind:itemId'.");
  }

  return {
    key: completionKey(kind, itemId),
    kind,
    itemId,
    level: source.level || null,
    title: source.title || null,
    source: source.source || null,
    metadata: source.metadata && typeof source.metadata === "object" ? source.metadata : null
  };
}

function publicCompletionRecord(record) {
  return {
    key: record.key,
    kind: record.kind,
    itemId: record.itemId,
    level: record.level || null,
    title: record.title || null,
    source: record.source || null,
    metadata: record.metadata || null,
    completedAt: record.completedAt
  };
}

function completedEntriesForLearner(learnerId) {
  if (!learnerId) return [];
  const store = loadProgressStore();
  const learner = store.learners[learnerId];
  if (!learner?.completed) return [];
  return Object.values(learner.completed).map(publicCompletionRecord);
}

function splitParamList(value) {
  return String(value || "")
    .split(/[,\s]+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function completionFilterFor(searchParams) {
  const learnerId = normalizeLearnerId(searchParams.get("learnerId") || searchParams.get("userId") || searchParams.get("deviceId"));
  const completedKeys = new Set();
  const untypedCompletedItemIds = new Set();
  const completedParams = [
    ...splitParamList(searchParams.get("completed")),
    ...splitParamList(searchParams.get("completedIds")),
    ...splitParamList(searchParams.get("excludeIds"))
  ];

  for (const value of completedParams) {
    const parsed = parseCompletionIdentifier(value);
    if (!parsed) continue;
    if (parsed.kind === "item") {
      untypedCompletedItemIds.add(parsed.itemId);
    } else {
      completedKeys.add(completionKey(parsed.kind, parsed.itemId));
    }
  }

  for (const record of completedEntriesForLearner(learnerId)) {
    completedKeys.add(record.key);
  }

  const includeCompleted = searchParams.get("includeCompleted") === "true" || searchParams.get("excludeCompleted") === "false";
  const explicitExclude = searchParams.get("excludeCompleted") === "true";
  const hasCompletedState = Boolean(learnerId) || completedKeys.size > 0 || untypedCompletedItemIds.size > 0;

  return {
    learnerId,
    shouldExclude: !includeCompleted && (explicitExclude || hasCompletedState),
    completedKeys,
    untypedCompletedItemIds
  };
}

function isCompletedItem(item, kind, filter) {
  if (!filter?.shouldExclude || !item?.id) return false;
  return filter.completedKeys.has(completionKey(kind, item.id))
    || filter.untypedCompletedItemIds.has(item.id);
}

function filterIncompleteItems(items, kind, filter) {
  if (!filter?.shouldExclude) return items;
  return items.filter((item) => !isCompletedItem(item, kind, filter));
}

function progressResponse(filter, total, visible) {
  if (!filter?.shouldExclude) return undefined;
  return {
    learnerId: filter.learnerId || null,
    excludeCompleted: true,
    completedCount: filter.completedKeys.size + filter.untypedCompletedItemIds.size,
    hiddenCompleted: Math.max(0, total - visible)
  };
}

function readRequestBody(req) {
  if (req.body && typeof req.body === "object" && !Buffer.isBuffer(req.body)) {
    return Promise.resolve(req.body);
  }

  if (typeof req.body === "string" || Buffer.isBuffer(req.body)) {
    return Promise.resolve(String(req.body));
  }

  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        reject(httpError(413, "Request body is too large."));
        req.destroy();
      }
    });
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}

async function readJSONBody(req) {
  const body = await readRequestBody(req);
  if (body && typeof body === "object" && !Buffer.isBuffer(body)) {
    return body;
  }

  const raw = String(body || "").trim();
  if (!raw) return {};

  try {
    return JSON.parse(raw);
  } catch {
    throw httpError(400, "Invalid JSON body.");
  }
}

const categoryMeta = {
  foundation: {
    label: "Foundation",
    defaultGoal: "Build the smallest usable blocks for understanding and producing English.",
    practice: "Match, repeat, listen, choose, and answer with very short phrases."
  },
  grammar: {
    label: "Grammar",
    defaultGoal: "Understand the structure, notice it in real input, and use it in short answers.",
    practice: "Study the pattern, compare examples, then complete and rewrite sentences."
  },
  skills: {
    label: "Skills",
    defaultGoal: "Use English to complete a communicative task at the right level.",
    practice: "Read or listen, plan a response, produce your answer, then review feedback."
  },
  use_of_english: {
    label: "Use of English",
    defaultGoal: "Train Cambridge-style control of vocabulary, grammar, collocation and sentence form.",
    practice: "Complete cloze tasks, transform sentences, correct errors and paraphrase."
  },
  listening: {
    label: "Listening",
    defaultGoal: "Recognize words, meaning, tone and detail in spoken English.",
    practice: "Listen once for gist, again for details, then shadow or complete missing words."
  },
  speaking: {
    label: "Speaking",
    defaultGoal: "Produce clear, natural spoken English with increasing fluency and control.",
    practice: "Repeat, shadow, answer prompts, compare pronunciation and extend your response."
  },
  writing: {
    label: "Writing",
    defaultGoal: "Write clear text for the task, level and audience.",
    practice: "Plan, write, get feedback, rewrite and notice recurring mistakes."
  },
  vocabulary: {
    label: "Vocabulary",
    defaultGoal: "Grow useful words, collocations and expressions by level and context.",
    practice: "Learn in chunks, use examples, review with spaced repetition and produce your own sentence."
  }
};

const levelMeta = [
  {
    id: "pre-a1",
    label: "Pre-A1",
    cambridge: "Pre A1 Starters style",
    description: "First contact with English: sounds, basic words, simple recognition and very short answers."
  },
  {
    id: "a1",
    label: "A1",
    cambridge: "A1 Movers / beginner CEFR",
    description: "Basic user: simple sentences about self, routines, places and immediate needs."
  },
  {
    id: "a2",
    label: "A2",
    cambridge: "A2 Key",
    description: "Basic user: everyday situations, short messages, simple past/future and familiar topics."
  },
  {
    id: "b1",
    label: "B1",
    cambridge: "B1 Preliminary",
    description: "Independent user: experiences, opinions, reasons, stories and common work/study situations."
  },
  {
    id: "b2",
    label: "B2",
    cambridge: "B2 First",
    description: "Independent user: clear argument, register control, inference, paraphrase and confident interaction."
  },
  {
    id: "c1",
    label: "C1",
    cambridge: "C1 Advanced",
    description: "Proficient user: nuanced language, complex texts, flexible register and precise expression."
  },
  {
    id: "c2",
    label: "C2",
    cambridge: "C2 Proficiency",
    description: "Proficient user: near-native flexibility, subtle tone, complex argument and stylistic control."
  },
  {
    id: "all",
    label: "All",
    cambridge: "Cross-level training",
    description: "Skill families that can be trained progressively from A1 to C2."
  }
];

const sourceBasis = [
  "CEFR level progression",
  "Cambridge-style exam task families",
  "British Council / EAQUALS Core Inventory used as curriculum inspiration",
  "User-provided Pre-A1 and A1 explanatory study guides",
  "Tatoeba authentic sentence API for real examples",
  "Datamuse API for word-bank expansion",
  "LanguageTool API for writing correction",
  "Locupom original summaries, examples and practice prompts"
];

const morningBriefContent = loadJSON(MORNING_BRIEF_CONTENT_PATH, {
  generatedAt: null,
  runId: null,
  readings: [],
  speakingPrompts: [],
  exercises: [],
  vocabulary: [],
  metadata: {}
});

const readingTopicsByLevel = {
  "Pre-A1": ["family", "colors", "school", "food"],
  A1: ["daily routines", "music", "friends", "home"],
  A2: ["travel plans", "weekend activities", "food markets", "healthy habits"],
  B1: ["community gardens", "city life", "local radio", "neighbourhood festivals"],
  B2: ["museum access", "cultural habits", "public transport", "environmental choices"],
  C1: ["urban memory", "creative discipline", "digital communities", "sustainable cities"],
  C2: ["public communication", "cultural nuance", "ethical technology", "institutional accountability"]
};

const localReadingTemplates = {
  "Pre-A1": [
    {
      title: "The blue notebook",
      estimatedMinutes: 2,
      content: "I have a blue notebook. I write one English word. I draw a picture. My teacher says the word. I say it too. Then I show the page to my friend.",
      question: {
        prompt: "What does the learner write?",
        options: ["One English word", "A long story", "A phone number"],
        answer: "One English word",
        explanation: "The text says the learner writes one English word."
      }
    },
    {
      title: "At the table",
      estimatedMinutes: 2,
      content: "There is a book on the table. There is a red pen next to the book. Ana opens the book. She points to a picture and says, 'apple'. Her brother smiles.",
      question: {
        prompt: "Where is the book?",
        options: ["On the table", "Under the bed", "In a bag"],
        answer: "On the table",
        explanation: "The first sentence says the book is on the table."
      }
    },
    {
      title: "My first song",
      estimatedMinutes: 2,
      content: "Tom likes one English song. The song is slow. He hears 'hello' and 'day'. He sings the words in the car. His mother sings with him.",
      question: {
        prompt: "Why can Tom sing the song?",
        options: ["It is slow.", "It is very old.", "It is in Spanish."],
        answer: "It is slow.",
        explanation: "The song is slow, so Tom can hear and sing some words."
      }
    }
  ],
  A1: [
    {
      title: "A simple study routine",
      estimatedMinutes: 3,
      content: "Mia studies English every morning. First, she listens to one short song. Then she writes five new words in her notebook. After that, she reads a small text and answers one question. She likes this routine because it is easy to repeat.",
      question: {
        prompt: "What does Mia do first?",
        options: ["She listens to a song.", "She watches a film.", "She calls a friend."],
        answer: "She listens to a song.",
        explanation: "The first step in her routine is listening to one short song."
      }
    },
    {
      title: "A quiet bus ride",
      estimatedMinutes: 3,
      content: "Leo studies on the bus because his ride to school takes twenty minutes. He does not use a big book. He opens a small app, reads three sentences, and repeats them quietly. At night, he checks the same sentences again. The practice is short, but he does it every day.",
      question: {
        prompt: "Why does Leo study on the bus?",
        options: ["His ride takes twenty minutes.", "He is a bus driver.", "His teacher is on the bus."],
        answer: "His ride takes twenty minutes.",
        explanation: "The text says his ride to school takes twenty minutes."
      }
    },
    {
      title: "A message from a friend",
      estimatedMinutes: 3,
      content: "Sofia gets a message from her friend Emma. The message is in English, but it is not difficult. Emma says she has a new guitar and wants to play a song on Saturday. Sofia understands the day, the instrument, and the plan. She answers with one short sentence: 'Great, see you Saturday!'",
      question: {
        prompt: "What does Emma want to do?",
        options: ["Play a song on Saturday.", "Buy a phone.", "Study for an exam."],
        answer: "Play a song on Saturday.",
        explanation: "Emma says she wants to play a song on Saturday."
      }
    }
  ],
  A2: [
    {
      title: "A weekend plan",
      estimatedMinutes: 4,
      content: "Lucas wants to improve his English this weekend, but he does not want to sit at a desk all day. On Saturday morning, he is going to read a short article about music. In the afternoon, he will meet a friend and describe the article in English. On Sunday, he plans to review the difficult words and write a short message about what he learned.",
      question: {
        prompt: "What will Lucas do with his friend?",
        options: ["Describe the article in English.", "Buy concert tickets.", "Study grammar for three hours."],
        answer: "Describe the article in English.",
        explanation: "The text says he will meet a friend and describe the article in English."
      }
    },
    {
      title: "The playlist experiment",
      estimatedMinutes: 4,
      content: "Nina usually listens to music while she cooks, but last week she tried something different. She chose three songs in English and wrote down words she could hear clearly. Some words were easy, such as 'home' and 'night'. Others were harder because the singer spoke quickly. After dinner, Nina looked up the difficult words and listened again. The second time, the songs felt less confusing.",
      question: {
        prompt: "What changed after Nina looked up the words?",
        options: ["The songs felt less confusing.", "The singer changed the lyrics.", "She stopped cooking."],
        answer: "The songs felt less confusing.",
        explanation: "After looking up the difficult words, she listened again and understood more."
      }
    },
    {
      title: "A new route to class",
      estimatedMinutes: 4,
      content: "Martin started walking to his English class instead of taking the train. The walk is longer, but he uses the time well. He listens to short dialogues and repeats useful phrases. At first, people in the street made him nervous, so he spoke very quietly. Now he feels more comfortable. He still makes mistakes, but he arrives at class already thinking in English.",
      question: {
        prompt: "Why does Martin walk to class?",
        options: ["He uses the time to practise English.", "The train is closed forever.", "His class is in a park."],
        answer: "He uses the time to practise English.",
        explanation: "The walk gives him time to listen and repeat phrases."
      }
    }
  ],
  B1: [
    {
      title: "Why real interests change the habit",
      estimatedMinutes: 6,
      content: "When Clara started learning English, she used only coursebooks. They gave her structure, but after a few weeks she noticed a problem: she could complete exercises without feeling that the language belonged to her. Later, she began reading short texts about artists, interviews, and the stories behind songs. The vocabulary was sometimes difficult, yet the context helped her guess meaning before checking a dictionary.\n\nThis changed the way she studied. Instead of memorising isolated expressions, she connected them to a situation, a voice, and a reason for speaking. She still used grammar notes, but she used them after reading, not before. That order made the grammar feel less abstract. For Clara, the most useful material was not the easiest material; it was material that gave her a reason to keep paying attention.",
      question: {
        prompt: "What helped Clara remember expressions more effectively?",
        options: ["Connecting them to meaningful situations.", "Avoiding grammar completely.", "Choosing only very easy texts."],
        answer: "Connecting them to meaningful situations.",
        explanation: "The text says context, situations and voices helped the expressions become memorable."
      }
    },
    {
      title: "The problem with perfect notes",
      estimatedMinutes: 6,
      content: "Javier kept a beautiful English notebook. Every page had colours, tables, and carefully copied rules. However, when he tried to speak, the notes did not help as much as he expected. He knew the rule for the present perfect, but he could not decide quickly whether a sentence needed it. His teacher suggested a small change: after every new rule, Javier had to find the same pattern in a song, a video, or a short article.\n\nAt first, this felt slower than simply copying examples. After two weeks, though, he began to notice patterns without looking for them. He heard 'I've never seen...' in an interview and understood why the speaker was talking about experience, not a finished moment. The notebook was still useful, but it became a map rather than the whole journey.",
      question: {
        prompt: "What was the teacher's main suggestion?",
        options: ["Find grammar patterns in real input.", "Stop writing notes forever.", "Study only long academic texts."],
        answer: "Find grammar patterns in real input.",
        explanation: "The teacher wanted Javier to connect rules with real examples from songs, videos or articles."
      }
    },
    {
      title: "A text that was almost too hard",
      estimatedMinutes: 6,
      content: "Emma chose an article about how musicians prepare for live performances. The first paragraph was easy, but the second included words she did not know: rehearsal, pressure, audience, and confidence. She almost closed the page. Then she tried a different strategy. First, she read the paragraph without stopping. Next, she underlined only the words that changed the main idea. Finally, she wrote a one-sentence summary in simple English.\n\nThe article did not suddenly become easy, but it became manageable. Emma realised that understanding a text does not always mean understanding every word immediately. Sometimes it means building enough meaning to continue. By the end, she had learned new vocabulary, but more importantly, she had learned a method for staying calm when a text becomes challenging.",
      question: {
        prompt: "What did Emma learn from the difficult article?",
        options: ["A method for continuing when a text is challenging.", "That difficult words should always be ignored.", "That summaries are never useful."],
        answer: "A method for continuing when a text is challenging.",
        explanation: "The passage focuses on Emma's strategy for managing difficulty."
      }
    },
    {
      title: "From translation to explanation",
      estimatedMinutes: 6,
      content: "For a long time, Tomas believed he understood English only if he could translate every sentence into Spanish. This made reading slow and tiring. One day, while reading about learning with music, he tried a new task: instead of translating the paragraph, he explained it in simpler English. His first explanation was not perfect, but it showed that he had understood the main point.\n\nThe new habit changed his confidence. Translation was still useful for checking details, but it was no longer the only goal. When Tomas explained ideas in English, he practised vocabulary, grammar, and organisation at the same time. He also noticed gaps in his knowledge more clearly. If he could not explain an idea simply, he returned to the text and read it again with a more specific purpose.",
      question: {
        prompt: "Why did explaining in English help Tomas?",
        options: ["It trained several skills at the same time.", "It made every text shorter.", "It removed the need to reread."],
        answer: "It trained several skills at the same time.",
        explanation: "The text says explanation practised vocabulary, grammar and organisation together."
      }
    }
  ],
  B2: [
    {
      title: "Choosing useful difficulty",
      estimatedMinutes: 7,
      content: "A common mistake in language learning is choosing material that is either too easy or far too difficult. Easy texts can build fluency, but they may not introduce enough new language. Very difficult texts can be motivating at first, yet they often become frustrating because the learner spends more time decoding than understanding.\n\nUseful difficulty sits between those extremes. A good reading text contains enough familiar language to keep meaning clear and enough unfamiliar language to stretch the learner's ability. This balance matters because attention is limited. If every sentence requires heavy effort, the learner has no energy left to notice tone, argument, or structure. If nothing requires effort, the learner finishes quickly but gains little. The best material creates productive tension: the reader can follow the message, but must still make intelligent decisions.",
      question: {
        prompt: "What does the passage mean by useful difficulty?",
        options: ["A balance between clarity and challenge.", "Texts with no unfamiliar language.", "Material that is intentionally confusing."],
        answer: "A balance between clarity and challenge.",
        explanation: "The passage argues for texts that are understandable but still stretch the learner."
      }
    },
    {
      title: "When technology becomes invisible",
      estimatedMinutes: 7,
      content: "The most effective learning technology is not always the most impressive one. A tool may have advanced features, colourful dashboards, and instant feedback, but still fail if it interrupts the learner's attention. In contrast, a simpler tool can be powerful when it helps the learner make one clear decision: what to read next, what to review, or what mistake to correct.\n\nThis is especially true for independent learners. They do not need constant novelty; they need continuity. If an app can remember their level, suggest material that is slightly above their comfort zone, and provide a reason to return tomorrow, it becomes part of a routine. The technology is successful precisely when it becomes less visible than the habit it supports.",
      question: {
        prompt: "According to the passage, when is learning technology most successful?",
        options: ["When it supports a clear learning habit.", "When it constantly shows new features.", "When it replaces learner attention."],
        answer: "When it supports a clear learning habit.",
        explanation: "The passage values technology that quietly supports continuity and useful decisions."
      }
    },
    {
      title: "The hidden value of partial understanding",
      estimatedMinutes: 7,
      content: "Many learners underestimate partial understanding. They read a paragraph, miss several words, and conclude that they have failed. In reality, partial understanding can be a productive stage, especially at B2. At this level, the learner is beginning to deal with texts that contain implication, contrast, and less predictable vocabulary. The goal is not to remove uncertainty immediately, but to manage it intelligently.\n\nA strong reader asks different questions while reading: Which words are essential? Which examples support the main claim? Which sentence changes the direction of the argument? These questions prevent the learner from treating every unknown word as equally important. Over time, the learner becomes more tolerant of ambiguity, which is a necessary skill for authentic reading.",
      question: {
        prompt: "What skill does the passage connect with partial understanding?",
        options: ["Managing ambiguity intelligently.", "Avoiding authentic texts.", "Memorising every unknown word first."],
        answer: "Managing ambiguity intelligently.",
        explanation: "The passage says uncertainty can be useful when the learner manages it with good reading questions."
      }
    },
    {
      title: "Why routines need variation",
      estimatedMinutes: 7,
      content: "A routine helps learners continue when motivation is low, but a routine that never changes can become mechanical. The challenge is to preserve the habit while varying the task. For example, a learner might read about music on Monday, technology on Tuesday, and personal goals on Wednesday. The structure remains stable: read, notice, summarise, review. The content changes enough to keep attention active.\n\nThis kind of variation matters because language is flexible. A phrase learned in one context may not sound natural in another. When learners meet similar grammar across different topics, they begin to understand not only what a structure means, but also where it belongs. Variation turns repetition from memorisation into transfer.",
      question: {
        prompt: "Why does the passage recommend variation inside a routine?",
        options: ["It helps learners transfer language across contexts.", "It removes the need for repetition.", "It makes grammar less important."],
        answer: "It helps learners transfer language across contexts.",
        explanation: "The passage says varied contexts help learners understand where language belongs."
      }
    }
  ],
  C1: [
    {
      title: "Attention as a learning strategy",
      estimatedMinutes: 8,
      content: "Advanced learners often assume that progress depends on collecting more sophisticated vocabulary. Vocabulary matters, of course, but progress also depends on attention: noticing how a writer builds contrast, how a speaker softens disagreement, or how a phrase changes tone in a particular context. This kind of attention turns ordinary input into evidence.\n\nInstead of simply understanding the message, the learner begins to observe the choices that make the message effective. A short article can reveal how an argument is staged; an interview can show how hesitation protects politeness; a song lyric can demonstrate how repetition creates emotional weight. At C1, improvement is less about adding more language and more about perceiving what the language is doing.",
      question: {
        prompt: "What does the passage suggest C1 learners should pay attention to?",
        options: ["How language choices create effects.", "Only rare vocabulary.", "Only the literal message."],
        answer: "How language choices create effects.",
        explanation: "The passage focuses on contrast, tone, politeness, argument and emotional weight."
      }
    },
    {
      title: "The discipline of nuance",
      estimatedMinutes: 8,
      content: "At an advanced level, the difference between two acceptable sentences can be subtle but meaningful. One sentence may sound direct and efficient; another may sound cautious, diplomatic, or distant. Learners who want to sound natural need to move beyond correctness and ask what a sentence does socially. Does it invite agreement? Does it challenge the listener? Does it hide uncertainty behind formal language?\n\nThis attention to nuance can feel slow at first because it requires interpretation rather than simple rule application. However, it also gives learners more control. They begin to choose language according to relationship, purpose, and context. In that sense, advanced reading is not passive. It is a rehearsal space for more precise speaking and writing.",
      question: {
        prompt: "What is the main claim of the passage?",
        options: ["Advanced learners need social and contextual control of language.", "Correct grammar is impossible to learn.", "Formal language is always the safest choice."],
        answer: "Advanced learners need social and contextual control of language.",
        explanation: "The passage argues that advanced control depends on purpose, relationship and nuance."
      }
    },
    {
      title: "Reading beyond agreement",
      estimatedMinutes: 8,
      content: "One sign of mature reading is the ability to understand a text without immediately agreeing or disagreeing with it. Less experienced readers often react too quickly: they accept a point because it sounds familiar, or reject it because it feels uncomfortable. Advanced readers delay that reaction. They ask how the argument has been built, what evidence has been selected, and which assumptions remain hidden.\n\nThis does not make reading cold or detached. On the contrary, it creates a more thoughtful form of engagement. The reader can admire a writer's technique while questioning the conclusion, or disagree with a claim while recognising the strength of its structure. Such reading develops intellectual flexibility, a skill that reaches far beyond language learning.",
      question: {
        prompt: "What does the passage describe as mature reading?",
        options: ["Delaying reaction to examine how an argument works.", "Agreeing with familiar ideas quickly.", "Rejecting difficult ideas immediately."],
        answer: "Delaying reaction to examine how an argument works.",
        explanation: "The passage says mature readers examine evidence, assumptions and structure before reacting."
      }
    }
  ],
  C2: [
    {
      title: "Precision beyond correctness",
      estimatedMinutes: 9,
      content: "At the highest levels of proficiency, correctness is no longer the whole story. A sentence may be grammatically flawless and still sound heavy, evasive, overly casual, or strangely theatrical. Expert users of English make constant micro-decisions about emphasis, rhythm, implication and register. They know when a plain verb is stronger than an ornate phrase, when understatement is more persuasive than intensity, and when a small shift in wording can change the social meaning of an entire exchange.\n\nThis is why C2 reading requires sensitivity to more than information. The reader must notice what is foregrounded, what is softened, and what is left unsaid. The best evidence of proficiency is not the ability to decorate language, but the ability to choose the least noisy form that still carries the intended force.",
      question: {
        prompt: "What does the passage argue about high-level English?",
        options: ["It requires control of nuance, rhythm and register.", "It depends mainly on decorative vocabulary.", "It is only about avoiding grammar mistakes."],
        answer: "It requires control of nuance, rhythm and register.",
        explanation: "The passage contrasts mere correctness with precise control of tone and social meaning."
      }
    },
    {
      title: "The ethics of eloquence",
      estimatedMinutes: 9,
      content: "Fluent language can clarify, but it can also conceal. A polished sentence may make a weak argument appear stronger than it is, especially when abstract nouns replace visible actions. For this reason, advanced readers should treat eloquence with both appreciation and suspicion. Style is not an ornament placed on top of meaning; it is one of the ways meaning is produced.\n\nA careful reader asks what the language makes easy to see and what it makes easy to ignore. Who is responsible for the action? Which terms are emotionally loaded? Where does the writer move from evidence to interpretation? These questions do not diminish the pleasure of reading. They deepen it by making the reader aware of the power that fluent language can exercise.",
      question: {
        prompt: "Why should advanced readers be cautious with eloquent language?",
        options: ["It can clarify ideas but also hide weak reasoning.", "It is always dishonest.", "It has no effect on meaning."],
        answer: "It can clarify ideas but also hide weak reasoning.",
        explanation: "The passage says polished language can make weak arguments appear stronger."
      }
    },
    {
      title: "Silence inside a sentence",
      estimatedMinutes: 9,
      content: "Sophisticated communication often depends on what is not said. A speaker may avoid naming a problem directly in order to preserve dignity, maintain ambiguity, or invite the listener to infer a conclusion. In writing, the same effect can be created through omission, passive structures, or strategically modest wording. These choices are not accidental gaps; they are part of the message.\n\nFor C2 learners, the challenge is to detect these silences without inventing meanings irresponsibly. The reader must distinguish between an implication supported by the text and a projection brought from outside it. That distinction is delicate, but it is central to advanced comprehension. The unsaid is not empty; it is a space where language, context and judgement meet.",
      question: {
        prompt: "What challenge does the passage identify for C2 learners?",
        options: ["Interpreting implication without projecting unsupported meanings.", "Avoiding all implied meaning.", "Replacing subtle language with direct commands."],
        answer: "Interpreting implication without projecting unsupported meanings.",
        explanation: "The passage says readers must distinguish textual implication from outside projection."
      }
    }
  ]
};

const readingVariationNotes = {
  "Pre-A1": [
    (topic) => `Today the word is about ${topic}.`,
    () => "The learner says the words again at home.",
    () => "The page is small, but the practice is good."
  ],
  A1: [
    (topic) => `This small habit helps with ${topic}.`,
    () => "The important part is doing a little every day.",
    () => "After a week, the learner can remember more words."
  ],
  A2: [
    (topic) => `This plan works because ${topic} becomes part of a real day, not only a classroom task.`,
    () => "The learner does not understand everything immediately, but the second reading is always clearer.",
    () => "A short review at the end helps turn new words into useful language."
  ],
  B1: [
    (topic) => `This is why ${topic} can be more than entertainment: it gives the learner a reason to notice language carefully. The topic creates memory hooks, so new expressions are connected to people, actions and emotions instead of floating alone on a list.`,
    () => "The method is simple, but it requires patience: first understand the general message, then return for the details. Learners who accept that order often read more confidently because they stop expecting perfect understanding from the first attempt.",
    () => "Progress appears when the learner stops treating mistakes as failure and starts treating them as information. A wrong guess can still show what the learner noticed, what they ignored, and which clue they should use next time.",
    () => "The key change is not speed. It is the ability to continue reading even when every sentence is not perfectly clear. That ability makes longer texts less intimidating and helps learners build independence."
  ],
  B2: [
    (topic) => `In a topic such as ${topic}, this balance is especially useful because the learner must follow ideas, examples and implications at the same time. The text should therefore create pressure without forcing the reader to abandon the main line of meaning.`,
    () => "The deeper skill is learning how to decide which difficulty deserves attention and which difficulty can wait. This is not laziness; it is strategic reading, because not every unknown word has the same importance.",
    () => "This kind of reading trains judgement: the learner must separate the central argument from supporting detail. Once that distinction becomes clearer, new vocabulary is easier to place inside the writer's purpose.",
    () => "The text becomes a controlled challenge, not because it is easy, but because it offers enough clues to keep interpretation moving. That movement is what prevents difficulty from turning into pure frustration."
  ],
  C1: [
    (topic) => `For a C1 reader, ${topic} is useful when it becomes a field for noticing stance, register and implied evaluation.`,
    () => "The learner's task is to notice how meaning is shaped, not merely to collect impressive phrases.",
    () => "At this level, comprehension includes the ability to explain why a writer chose one formulation instead of another.",
    () => "The reading is successful when it changes the learner's attention, not only the learner's vocabulary list."
  ],
  C2: [
    (topic) => `At C2, ${topic} is not just content; it is a lens through which precision, implication and rhetorical control can be examined.`,
    () => "The most advanced question is often not 'What does this mean?' but 'What does this wording allow the writer to do?'",
    () => "Such reading rewards restraint: the learner must interpret boldly enough to notice implication, yet carefully enough not to invent it.",
    () => "The value of the passage lies in the pressure it places on judgement, nuance and stylistic awareness."
  ]
};

const readingBridgeParagraphs = {
  "Pre-A1": [
    (topic) => `The teacher asks one more question about ${topic}. The learner listens, points, and answers with a short word.`,
    () => "Then the learner closes the book. The words are still small, but they are easier to remember after saying them aloud."
  ],
  A1: [
    (topic) => `The topic is ${topic}, so the learner can connect the new words to a normal day. This makes the text easier to remember.`,
    () => "The learner reads the text again in the evening. Some words are still new, but the general meaning is clear."
  ],
  A2: [
    (topic) => `Because the text is about ${topic}, the learner can imagine a real situation and not only a grammar exercise. That context makes the new vocabulary more useful.`,
    () => "The second reading is slower and more careful. This time, the learner looks for the reason behind each action, not only the new words."
  ],
  B1: [
    (topic) => `The topic of ${topic} gives the learner more than vocabulary. It creates a context where grammar, meaning and personal interest work together, so the text feels connected instead of random.`,
    () => "A useful reading habit has two moments: first, follow the message without stopping too much; later, return to the parts that carried the most meaning."
  ],
  B2: [
    (topic) => `In a B2 text about ${topic}, the reader is expected to follow contrast, cause and consequence. The challenge is not only to understand facts, but to see how the writer connects them.`,
    () => "At this level, a paragraph often contains more than one job: it may give an example, limit a claim, and prepare the next idea at the same time."
  ],
  C1: [
    (topic) => `A C1 reader can use ${topic} as a lens for analysing stance and emphasis. The point is not merely to understand the text, but to notice how the writer guides interpretation.`,
    () => "The middle of the text is where subtle control often appears: a concession, a shift in register, or a carefully placed example can change the force of the whole argument."
  ],
  C2: [
    (topic) => `At C2, a text about ${topic} should invite close attention to what is explicit, what is implied, and what remains deliberately unresolved.`,
    () => "The reader's task is interpretive as much as linguistic: every choice of wording may affect responsibility, emphasis, distance or persuasion."
  ]
};

const readingMinimumWords = {
  B1: 160,
  B2: 190,
  C1: 190,
  C2: 190
};

const recentReadingSelections = new Map();

const plans = [
  {
    level: "Pre-A1",
    category: "foundation",
    titles: [
      "Alphabet and spelling",
      "Numbers 1-100",
      "Colours",
      "Days, months and dates",
      "Classroom language",
      "Basic greetings",
      "Introducing yourself",
      "Simple instructions",
      "Personal information",
      "Basic sounds and pronunciation",
      "Very short listening",
      "Matching words to pictures"
    ]
  },
  {
    level: "A1",
    category: "grammar",
    titles: [
      "Verb to be",
      "Subject pronouns",
      "Possessive adjectives",
      "Articles",
      "Singular and plural nouns",
      "This / that / these / those",
      "There is / there are",
      "Have / have got",
      "Present simple",
      "Basic imperatives",
      "Can / can't",
      "Basic prepositions",
      "Question words",
      "Basic word order",
      "Adverbs of frequency"
    ]
  },
  {
    level: "A1",
    category: "skills",
    titles: [
      "Describing yourself",
      "Describing family",
      "Talking about routines",
      "Saying what you like",
      "Asking simple questions",
      "Understanding short instructions",
      "Writing simple sentences",
      "Reading short texts",
      "Listening for keywords",
      "Basic speaking responses"
    ]
  },
  {
    level: "A2",
    category: "grammar",
    titles: [
      "Past simple",
      "Present continuous",
      "Present simple vs present continuous",
      "Future with going to",
      "Future with will",
      "Countable and uncountable nouns",
      "Some / any",
      "Much / many / a lot of",
      "Comparatives and superlatives",
      "Object pronouns",
      "Possessive pronouns",
      "Should / must / have to",
      "Like / love / hate + -ing",
      "Infinitive of purpose",
      "Basic phrasal verbs",
      "Basic linking words"
    ]
  },
  {
    level: "A2",
    category: "skills",
    titles: [
      "Describing photos",
      "Giving directions",
      "Making requests",
      "Making invitations",
      "Accepting and refusing",
      "Writing short messages",
      "Writing informal emails",
      "Talking about past events",
      "Talking about plans",
      "Understanding short conversations",
      "Reading notices and signs",
      "Describing places",
      "Describing people"
    ]
  },
  {
    level: "B1",
    category: "grammar",
    titles: [
      "Present perfect",
      "Present perfect vs past simple",
      "Present perfect with ever / never / just / yet / already",
      "Past continuous",
      "Past simple vs past continuous",
      "Used to",
      "First conditional",
      "Second conditional",
      "Passive voice",
      "Reported speech",
      "Relative clauses",
      "Gerunds and infinitives",
      "Modals of deduction",
      "Too / enough",
      "So / such",
      "Question tags",
      "Indirect questions",
      "Connectors"
    ]
  },
  {
    level: "B1",
    category: "skills",
    titles: [
      "Storytelling",
      "Describing experiences",
      "Giving opinions with reasons",
      "Agreeing and disagreeing politely",
      "Making suggestions",
      "Giving advice",
      "Explaining preferences",
      "Writing informal letters",
      "Writing basic articles",
      "Writing short reviews",
      "Speaking from prompts",
      "Comparing options",
      "Reading for gist",
      "Listening for detail",
      "Basic paraphrasing"
    ]
  },
  {
    level: "B2",
    category: "grammar",
    titles: [
      "Past perfect",
      "Past perfect continuous",
      "Future continuous",
      "Future perfect",
      "Third conditional",
      "Mixed conditionals",
      "Advanced passive voice",
      "Causative have/get something done",
      "Reported questions",
      "Wish / if only",
      "Regret structures",
      "Modal perfects",
      "Defining vs non-defining relative clauses",
      "Participle clauses",
      "Inversion after negative adverbials",
      "Advanced phrasal verbs",
      "Discourse markers"
    ]
  },
  {
    level: "B2",
    category: "skills",
    titles: [
      "Essay writing",
      "Article writing",
      "Review writing",
      "Report writing",
      "Formal and informal emails",
      "Comparing and contrasting",
      "Speculating from images",
      "Supporting arguments",
      "Summarising short texts",
      "Inferring meaning",
      "Recognising attitude and opinion",
      "Advanced listening for detail",
      "Using register appropriately",
      "Paraphrasing sentences",
      "Expanding answers naturally"
    ]
  },
  {
    level: "C1",
    category: "grammar",
    titles: [
      "Cleft sentences",
      "Emphatic structures",
      "Advanced inversion",
      "Nominalisation",
      "Hedging language",
      "Ellipsis and substitution",
      "Fronting",
      "Complex noun phrases",
      "Reduced relative clauses",
      "Advanced conditionals",
      "Subjunctive forms",
      "Concession clauses",
      "Advanced passive reporting",
      "Complex linking devices",
      "Register and tone control"
    ]
  },
  {
    level: "C1",
    category: "skills",
    titles: [
      "Discursive essays",
      "Proposals",
      "Reports",
      "Formal letters",
      "Academic-style writing",
      "Nuanced opinions",
      "Evaluating arguments",
      "Synthesising information",
      "Summarising complex texts",
      "Understanding implied meaning",
      "Recognising tone and attitude",
      "Speaking fluently under pressure",
      "Developing long turns",
      "Reformulating ideas",
      "Using precise vocabulary"
    ]
  },
  {
    level: "C2",
    category: "grammar",
    titles: [
      "Subtle tense and aspect choices",
      "Advanced modality",
      "Fine distinctions in conditionals",
      "Complex clause structures",
      "Stylistic inversion",
      "Rhetorical emphasis",
      "Idiomatic grammar patterns",
      "Highly flexible register",
      "Advanced cohesion",
      "Elliptical structures",
      "Formal and literary structures",
      "Precision with articles and determiners",
      "Advanced collocational grammar"
    ]
  },
  {
    level: "C2",
    category: "skills",
    titles: [
      "Argumentative essays",
      "Critical reviews",
      "Professional reports",
      "Academic summaries",
      "Stylistic rewriting",
      "Summarising dense texts",
      "Interpreting irony and humour",
      "Recognising rhetorical devices",
      "Understanding implicit stance",
      "Debating complex topics",
      "Speaking with nuance",
      "Adapting tone to audience",
      "Editing for style",
      "Producing polished long-form writing",
      "Handling abstract topics"
    ]
  },
  {
    level: "All",
    category: "use_of_english",
    titles: [
      "Multiple-choice cloze",
      "Open cloze",
      "Word formation",
      "Key word transformations",
      "Sentence transformations",
      "Error correction",
      "Collocations",
      "Fixed expressions",
      "Phrasal verbs",
      "Prepositional phrases",
      "Register choice",
      "Linking devices",
      "Paraphrasing",
      "Rewriting for emphasis",
      "Rewriting for formality"
    ]
  },
  {
    level: "All",
    category: "listening",
    titles: [
      "Listening for gist",
      "Listening for detail",
      "Identifying keywords",
      "Predicting missing words",
      "Recognising connected speech",
      "Weak forms",
      "Sentence stress",
      "Intonation",
      "Understanding fast speech",
      "Understanding accents",
      "Identifying attitude",
      "Identifying emotion",
      "Inferring meaning",
      "Following long turns",
      "Understanding implied meaning"
    ]
  },
  {
    level: "All",
    category: "speaking",
    titles: [
      "Pronunciation of individual sounds",
      "Word stress",
      "Sentence stress",
      "Rhythm",
      "Intonation",
      "Shadowing",
      "Short answers",
      "Long turns",
      "Describing images",
      "Comparing images",
      "Asking follow-up questions",
      "Giving opinions",
      "Agreeing and disagreeing",
      "Speculating",
      "Negotiating",
      "Repairing mistakes",
      "Using fillers naturally",
      "Fluency chunks",
      "Register in speech"
    ]
  },
  {
    level: "All",
    category: "writing",
    titles: [
      "Simple sentences",
      "Paragraph structure",
      "Descriptions",
      "Narratives",
      "Informal emails",
      "Formal emails",
      "Articles",
      "Reviews",
      "Essays",
      "Reports",
      "Proposals",
      "Summaries",
      "Argument structure",
      "Topic sentences",
      "Supporting details",
      "Cohesion",
      "Avoiding repetition",
      "Formal vs informal tone",
      "Editing and proofreading",
      "Style improvement"
    ]
  },
  {
    level: "All",
    category: "vocabulary",
    titles: [
      "High-frequency verbs",
      "Daily routines",
      "Family and relationships",
      "Feelings and emotions",
      "Food and restaurants",
      "Travel and transport",
      "Work and study",
      "Technology",
      "Health",
      "Money",
      "Education",
      "Environment",
      "Culture and entertainment",
      "Music vocabulary",
      "Opinion vocabulary",
      "Argument vocabulary",
      "Word families",
      "Prefixes and suffixes",
      "False friends",
      "Collocations",
      "Idioms",
      "Topic vocabulary by CEFR level"
    ]
  }
];

function guideOverride({
  summary,
  pattern,
  examples,
  commonMistakes,
  learningObjectives,
  practiceIdeas,
  searchTerm,
  quizQuestion,
  quizAnswer
}) {
  const safeExamples = examples || [];
  const safeMistakes = commonMistakes || [];
  const answer = quizAnswer || "Use meaning, form and context together.";

  return {
    summary,
    pattern,
    examples: safeExamples,
    commonMistakes: safeMistakes,
    learningObjectives: learningObjectives || [
      "Understand when this topic is useful.",
      "Recognize the topic in a short A1-level context.",
      "Produce one short sentence or answer with the same pattern."
    ],
    lessonBlocks: [
      {
        title: "1. When to use it",
        body: summary
      },
      {
        title: "2. Key form",
        body: pattern
      },
      {
        title: "3. Guided examples",
        body: safeExamples.slice(0, 3).join(" | ")
      },
      {
        title: "4. Watch out",
        body: safeMistakes.join(" ")
      }
    ],
    practiceIdeas: practiceIdeas || [
      "Copy the examples, then change one word in each sentence.",
      "Say three short answers aloud without looking.",
      "Write one personal sentence and check it before moving on."
    ],
    practiceTasks: [
      {
        id: "guided_choice",
        kind: "multiple_choice",
        title: "Notice the use",
        instruction: "Choose the best description.",
        prompt: safeExamples[0] || pattern,
        options: [
          answer,
          "Only translate the sentence word by word.",
          "Ignore the form and memorize the title only."
        ],
        answer,
        explanation: "The study guides connect each topic with a real use, a clear form and short production."
      },
      {
        id: "pattern_control",
        kind: "sentence_builder",
        title: "Control the pattern",
        instruction: "Use the pattern to build or rewrite one short sentence.",
        prompt: pattern,
        options: [
          pattern,
          "random words without order",
          "a long sentence with no clear subject"
        ],
        answer: pattern,
        explanation: "At Pre-A1 and A1, short correct chunks are more useful than long translated sentences."
      },
      {
        id: "production",
        kind: "production",
        title: "Your turn",
        instruction: "Write one short personal sentence using this topic.",
        prompt: "Make it true for you, then check spelling, subject and word order.",
        options: [],
        answer: "",
        explanation: "Personal production helps the topic move from recognition to real use."
      }
    ],
    searchTerm,
    quiz: {
      question: quizQuestion || "What should you focus on first?",
      options: [
        answer,
        "Only memorising isolated words.",
        "Making the longest sentence possible."
      ],
      answer,
      explanation: "The safest path is: understand the use, control the form, then produce a short sentence."
    }
  };
}

const pdfGuideCustom = {
  alphabet_and_spelling: guideOverride({
    summary: "Use the English alphabet to spell names, surnames, emails, usernames and unfamiliar words. At Pre-A1, spelling lets you communicate even when you do not know a full explanation.",
    pattern: "How do you spell it? -> letter + letter + letter | double + letter",
    examples: ["How do you spell your name?", "M-A-R-I-A.", "A, double N, A."],
    commonMistakes: ["Confusing letter names with the sound of the letter inside a word.", "Forgetting useful spelling words like capital letter, small letter, at, dot and hyphen."],
    searchTerm: "spell name",
    quizAnswer: "Spell the word slowly using letter names."
  }),
  numbers_1_100: guideOverride({
    summary: "Use numbers 1-100 for age, pages, phone numbers, classroom tasks, prices and simple quantities.",
    pattern: "one-ten -> eleven-nineteen -> twenty, thirty... + one-nine",
    examples: ["I am thirteen.", "Open your book on page fourteen.", "My phone number is five, six, two."],
    commonMistakes: ["Confusing teen numbers with ten numbers, like thirteen and thirty.", "Writing numbers as digits but not being able to say them aloud."],
    searchTerm: "thirteen thirty",
    quizAnswer: "Listen for stress and say teen/ten numbers carefully."
  }),
  colours: guideOverride({
    summary: "Use colours to describe objects, clothes, pictures and classroom items.",
    pattern: "It is + colour | colour + noun | adjective before noun",
    examples: ["It is red.", "This is a blue pen.", "The books are green."],
    commonMistakes: ["Putting the colour after the noun: say a red pen, not a pen red.", "Forgetting a/an before one singular object."],
    searchTerm: "red pen",
    quizAnswer: "Put the colour before the noun."
  }),
  days_months_and_dates: guideOverride({
    summary: "Use days, months and simple dates to talk about classes, birthdays, schedules and events.",
    pattern: "on + day/date | in + month | ordinal numbers for dates",
    examples: ["English class is on Monday.", "My birthday is in July.", "Christmas is in December."],
    commonMistakes: ["Using in with days: say on Monday.", "Forgetting capital letters for days and months."],
    searchTerm: "on Monday",
    quizAnswer: "Use on for days and in for months."
  }),
  classroom_language: guideOverride({
    summary: "Use classroom language to ask for repetition, meaning, spelling, help and permission during a lesson.",
    pattern: "Can you + base verb, please? | I don't understand | What does ... mean?",
    examples: ["Can you repeat, please?", "I don't understand.", "How do you spell green?"],
    commonMistakes: ["Staying silent instead of asking for repetition or help.", "Using What means...? instead of What does ... mean?"],
    searchTerm: "can you repeat please",
    quizAnswer: "Ask for help with a short classroom phrase."
  }),
  basic_greetings: guideOverride({
    summary: "Use greetings and farewells to start and end simple conversations politely.",
    pattern: "Hello/Hi + name | How are you? -> I'm fine, thanks. And you?",
    examples: ["Hello, Leo.", "I'm fine, thanks. And you?", "See you tomorrow."],
    commonMistakes: ["Using Good night as a greeting instead of a farewell.", "Answering How are you? with only yes/no."],
    searchTerm: "how are you",
    quizAnswer: "Answer with a short phrase and return the question."
  }),
  introducing_yourself: guideOverride({
    summary: "Use short personal sentences to give your name, age, city, country, role, language and one thing you like.",
    pattern: "My name is... | I am ... years old | I am from... | I like...",
    examples: ["My name is Daniel.", "I'm thirteen years old.", "I speak Spanish and I like music."],
    commonMistakes: ["Saying I have 13 years instead of I am 13 years old.", "Using nationality when the question asks for country."],
    searchTerm: "my name is",
    quizAnswer: "Use short be sentences about yourself."
  }),
  simple_instructions: guideOverride({
    summary: "Understand and use simple classroom instructions for actions like listen, repeat, write, circle, match, open and close.",
    pattern: "verb + object | don't + base verb",
    examples: ["Listen to the audio.", "Write your name.", "Don't look at the answers."],
    commonMistakes: ["Adding you before every imperative when it is not needed.", "Making negative instructions without don't."],
    searchTerm: "open your book",
    quizAnswer: "Start with the base verb for positive instructions."
  }),
  personal_information: guideOverride({
    summary: "Ask and answer basic personal information for forms and short conversations: name, surname, age, country, city, birthday, phone and email.",
    pattern: "What is your...? | Where are you from? | When is your birthday?",
    examples: ["What's your surname?", "I live in Lima.", "My birthday is on 10 June."],
    commonMistakes: ["Mixing where are you from with where do you live.", "Forgetting that email and phone answers can be spelled or read slowly."],
    searchTerm: "where are you from",
    quizAnswer: "Match each question to the type of personal data it asks for."
  }),
  basic_sounds_and_pronunciation: guideOverride({
    summary: "Build basic pronunciation habits: listen first, notice word stress, and practise difficult sounds in short chunks.",
    pattern: "listen -> mark stress -> repeat by chunks -> compare",
    examples: ["TEA-cher", "STU-dent", "Can you repeat, please?"],
    commonMistakes: ["Pronouncing every English letter like Spanish.", "Ignoring word stress and saying every syllable equally."],
    searchTerm: "word stress English",
    quizAnswer: "Listen first and repeat in short chunks."
  }),
  very_short_listening: guideOverride({
    summary: "Practise very short listening by predicting the type of answer, finding keywords and ignoring extra words.",
    pattern: "look at the question -> predict -> listen for keywords -> answer shortly",
    examples: ["Name: Emma.", "Age: 12.", "Instruction: Open your book."],
    commonMistakes: ["Trying to understand every word in a tiny audio.", "Answering before checking what the question asks."],
    searchTerm: "listening keywords",
    quizAnswer: "Listen for the specific keyword the question needs."
  }),
  matching_words_to_pictures: guideOverride({
    summary: "Match basic words to pictures by identifying objects, people, actions and the easiest known words first.",
    pattern: "look -> name objects/actions -> match easy words -> check the unused options",
    examples: ["book -> libro", "chair -> silla", "The student opens a book."],
    commonMistakes: ["Matching the first word too quickly without checking all options.", "Ignoring action words in pictures."],
    searchTerm: "book chair apple",
    quizAnswer: "Identify the object or action before choosing."
  }),
  verb_to_be: guideOverride({
    summary: "Use be to say who someone is, how someone feels, age, origin, job, location and simple descriptions.",
    pattern: "subject + am/is/are + complement | Am/Is/Are + subject + complement?",
    examples: ["I am 15.", "She is my sister.", "Are you ready?"],
    commonMistakes: ["Saying I have 14 years old instead of I am 14 years old.", "Using do in be questions: say Are you happy?, not Do you are happy?"],
    searchTerm: "I am",
    quizAnswer: "Choose am, is or are according to the subject."
  }),
  subject_pronouns: guideOverride({
    summary: "Use subject pronouns to avoid repeating names and to show who does the action.",
    pattern: "I / you / he / she / it / we / they + verb",
    examples: ["Laura is from Peru. She is 13.", "The classroom is big. It is clean.", "My friends and I are happy. We are at home."],
    commonMistakes: ["Repeating the noun and pronoun together.", "Using they for one object when it should be it."],
    searchTerm: "she is",
    quizAnswer: "Replace repeated nouns with the correct subject pronoun."
  }),
  possessive_adjectives: guideOverride({
    summary: "Use possessive adjectives before nouns to show who something belongs to.",
    pattern: "my/your/his/her/its/our/their + noun",
    examples: ["My surname is Gomez.", "Her brother is 10.", "Their teacher is Mr. Clark."],
    commonMistakes: ["Using he or she before a noun instead of his or her.", "Writing its my pencil instead of It's my pencil or my pencil."],
    searchTerm: "my name",
    quizAnswer: "Put the possessive adjective before the noun."
  }),
  articles: guideOverride({
    summary: "Use a/an for one non-specific singular thing, the for a known thing, and no article for many general ideas.",
    pattern: "a/an + singular noun | the + known noun | no article + general plural/uncountable",
    examples: ["I have an umbrella.", "This is a book. The book is blue.", "I like football."],
    commonMistakes: ["Using a before vowel sounds: say an apple.", "Using the for general plural nouns: I like cats, not I like the cats."],
    searchTerm: "an apple",
    quizAnswer: "Use a/an for first mention and the when the thing is known."
  }),
  singular_and_plural_nouns: guideOverride({
    summary: "Use singular and plural nouns to talk about one thing or more than one thing, including regular and common irregular forms.",
    pattern: "singular noun -> plural noun: -s/-es/-ies or irregular",
    examples: ["one book, two books", "one watch, two watches", "one child, two children"],
    commonMistakes: ["Adding s to irregular plurals like childs.", "Forgetting that the verb changes with singular/plural nouns."],
    searchTerm: "plural nouns children",
    quizAnswer: "Check whether the noun is one thing or more than one."
  }),
  this_that_these_and_those: guideOverride({
    summary: "Use this/these for things near you and that/those for things farther away.",
    pattern: "this/that + singular | these/those + plural",
    examples: ["This is my bag.", "These are new pencils.", "Those are my classmates."],
    commonMistakes: ["Using this with plural nouns.", "Forgetting to use are with these and those."],
    searchTerm: "this is these are",
    quizAnswer: "Choose by distance and singular/plural."
  }),
  there_is_there_are: guideOverride({
    summary: "Use there is and there are to say that something exists or is present in a place.",
    pattern: "there is + singular/uncountable | there are + plural",
    examples: ["There is a park near here.", "There are three bedrooms.", "Is there a bus stop?"],
    commonMistakes: ["Using there are with one singular noun.", "Using any in an affirmative sentence like There are any shops."],
    searchTerm: "there is",
    quizAnswer: "Use there is for one thing and there are for more than one."
  }),
  have_have_got: guideOverride({
    summary: "Use have and have got for possession, family relationships, physical features and some routines.",
    pattern: "subject + have/has + noun | subject + have/has got + noun",
    examples: ["I have a new bag.", "She has two brothers.", "Have you got a pencil?"],
    commonMistakes: ["Using has after does: say Does she have a phone?", "Mixing do with have got: say Have you got..., not Do you have got..."],
    searchTerm: "have got",
    quizAnswer: "Use has with he/she/it and have with I/you/we/they."
  }),
  present_simple: guideOverride({
    summary: "Use present simple for routines, facts, likes, habits and things that happen regularly.",
    pattern: "subject + verb(s) | do/does + subject + base verb?",
    examples: ["I live in Buenos Aires.", "She studies English.", "Do you like music?"],
    commonMistakes: ["Forgetting -s with he, she and it.", "Using be before normal verbs: say I play, not I am play."],
    searchTerm: "every day",
    quizAnswer: "Use base verb for I/you/we/they and -s for he/she/it."
  }),
  basic_imperatives: guideOverride({
    summary: "Use imperatives to give simple instructions, classroom commands and short warnings.",
    pattern: "base verb + object | don't + base verb",
    examples: ["Open your book.", "Listen to the teacher.", "Don't use your phone."],
    commonMistakes: ["Starting with you in ordinary commands.", "Using no before a verb instead of don't."],
    searchTerm: "open your book",
    quizAnswer: "Start positive imperatives with the base verb."
  }),
  can_cant: guideOverride({
    summary: "Use can and can't for ability, permission and simple possibility.",
    pattern: "subject + can/can't + base verb | Can + subject + base verb?",
    examples: ["I can sing.", "She can't drive.", "Can you help me?"],
    commonMistakes: ["Adding to after can.", "Changing can with he/she/it: say he can play, not he cans."],
    searchTerm: "can you",
    quizAnswer: "Use the base verb after can or can't."
  }),
  basic_prepositions: guideOverride({
    summary: "Use basic prepositions to describe place and simple time relationships.",
    pattern: "in/on/under/next to/between/behind + noun",
    examples: ["The phone is in the bag.", "The cat is under the chair.", "The bank is between the school and the supermarket."],
    commonMistakes: ["Confusing in and on for physical position.", "Forgetting that prepositions depend on the relationship, not only the Spanish word."],
    searchTerm: "in on under",
    quizAnswer: "Choose the preposition that describes the relationship."
  }),
  question_words: guideOverride({
    summary: "Use question words to ask for information: thing, place, person, time, reason, manner, age and quantity.",
    pattern: "question word + auxiliary/be + subject + verb/complement?",
    examples: ["Where do you live?", "What is your phone number?", "How old are you?"],
    commonMistakes: ["Putting words in Spanish order.", "Using why without do/does in present simple questions."],
    searchTerm: "where do you",
    quizAnswer: "Choose the question word by the type of answer you need."
  }),
  basic_word_order: guideOverride({
    summary: "Use basic English word order so short sentences and questions are understandable.",
    pattern: "affirmative: subject + verb + object | question: auxiliary/be/can + subject + verb",
    examples: ["I like music.", "She is my friend.", "Where do you live?"],
    commonMistakes: ["Putting adjectives after nouns: say a small dog.", "Putting the subject at the end of basic sentences."],
    searchTerm: "I like music",
    quizAnswer: "Start normal statements with the subject."
  }),
  adverbs_of_frequency: guideOverride({
    summary: "Use adverbs of frequency to say how often something happens.",
    pattern: "subject + frequency adverb + main verb | subject + be + frequency adverb",
    examples: ["I always go to school.", "She is never late.", "We sometimes play football."],
    commonMistakes: ["Putting always after the object.", "Forgetting third-person -s because an adverb is present."],
    searchTerm: "always usually sometimes",
    quizAnswer: "Place the adverb before the main verb, but after be."
  }),
  describing_yourself: guideOverride({
    summary: "Describe yourself with short A1 sentences about name, age, city, role, family, personality and likes.",
    pattern: "My name is... + I am... + I live in... + I like...",
    examples: ["My name is Ana.", "I am 14.", "I live in Lima and I like music."],
    commonMistakes: ["Writing sentence fragments without a subject.", "Forgetting capital letters for I, names and countries."],
    searchTerm: "my name is",
    quizAnswer: "Use short complete sentences about yourself."
  }),
  describing_family: guideOverride({
    summary: "Describe family members using family vocabulary, possessives, ages, likes and simple routines.",
    pattern: "my + family member + is/has/likes/plays",
    examples: ["My sister is 8.", "His mother works in a school.", "My parents are from Peru."],
    commonMistakes: ["Using are with one family member.", "Forgetting -s in present simple for he/she."],
    searchTerm: "my sister",
    quizAnswer: "Use possessives and the correct verb form."
  }),
  talking_about_routines: guideOverride({
    summary: "Talk about daily routines with present simple, times and sequence words.",
    pattern: "First/Then/After that/Finally + subject + present simple",
    examples: ["I get up at 7.", "Then I have breakfast.", "Finally, I go to bed."],
    commonMistakes: ["Using present continuous for normal routines.", "Using in with clock times instead of at."],
    searchTerm: "get up at",
    quizAnswer: "Use present simple and sequence words."
  }),
  saying_what_you_like: guideOverride({
    summary: "Say likes and dislikes with simple reasons and short follow-up answers.",
    pattern: "subject + like/love/hate + noun or -ing | because + reason",
    examples: ["I like English.", "She likes tennis.", "I don't like coffee."],
    commonMistakes: ["Using like + base verb when -ing is needed.", "Forgetting does/doesn't with he and she."],
    searchTerm: "I like",
    quizAnswer: "Use like plus a noun or verb-ing."
  }),
  asking_simple_questions: guideOverride({
    summary: "Ask simple questions to get basic information and keep a short conversation going.",
    pattern: "be questions | do/does questions | can questions",
    examples: ["Are you from Argentina?", "Do you like music?", "Can you swim?"],
    commonMistakes: ["Answering with unrelated information.", "Using the wrong helper for the verb type."],
    searchTerm: "do you like",
    quizAnswer: "Choose be, do/does or can based on the question."
  }),
  understanding_short_instructions: guideOverride({
    summary: "Understand short written or spoken instructions by noticing the action verb first.",
    pattern: "verb + object/details | don't + verb",
    examples: ["Complete the sentences.", "Underline the verbs.", "Don't open your book."],
    commonMistakes: ["Reading every word and missing the action verb.", "Confusing common classroom verbs like write, read, circle and tick."],
    searchTerm: "complete the sentences",
    quizAnswer: "Find the action verb first."
  }),
  writing_simple_sentences: guideOverride({
    summary: "Write simple complete sentences with capital letters, subject, verb and punctuation.",
    pattern: "capital letter + subject + verb + complement + full stop",
    examples: ["I am from Argentina.", "My birthday is in July.", "She likes English."],
    commonMistakes: ["Forgetting capital I and country names.", "Joining ideas without punctuation or connectors."],
    searchTerm: "I am from",
    quizAnswer: "Check capital letter, subject, verb and final punctuation."
  }),
  reading_short_texts: guideOverride({
    summary: "Read short A1 texts by finding names, ages, places, family words, routines, likes and negatives.",
    pattern: "read question -> scan for keyword -> confirm in the text -> answer shortly",
    examples: ["Ben lives in Dublin.", "He goes to school by bus.", "Lily is his sister."],
    commonMistakes: ["Translating every word instead of looking for the answer.", "Answering from memory instead of returning to the text."],
    searchTerm: "short text lives",
    quizAnswer: "Go back to the text and find the keyword."
  }),
  listening_for_keywords: guideOverride({
    summary: "Listen for keywords such as age, city, likes, phone numbers, birthdays, food and class times.",
    pattern: "predict answer type -> listen for keyword -> write the short answer",
    examples: ["Age: fourteen.", "City: Dublin.", "Class starts at nine."],
    commonMistakes: ["Trying to understand every word in the audio.", "Missing negatives or confusing similar numbers."],
    searchTerm: "listening for keywords",
    quizAnswer: "Predict the answer type before listening."
  }),
  basic_speaking_responses: guideOverride({
    summary: "Give short speaking responses to questions with be, do/does and can, then add one small detail when possible.",
    pattern: "Yes/No + subject + auxiliary | short answer + one detail",
    examples: ["Yes, I am.", "No, I don't.", "Yes, she can."],
    commonMistakes: ["Answering a be question with do.", "Stopping at one word when a short answer is expected."],
    searchTerm: "yes I do",
    quizAnswer: "Match the short answer to the auxiliary in the question."
  })
};

const baseCustom = {
  "verb_to_be": {
    summary: "Use be to identify people, describe states, give age, talk about feelings and say where someone or something is.",
    pattern: "subject + am/is/are + complement",
    examples: [
      "I am ready for the lesson.",
      "She is from Argentina.",
      "They are at the concert."
    ],
    commonMistakes: [
      "Do not say 'I is'. Use 'I am'.",
      "English usually needs a subject: say 'It is late', not only 'is late'."
    ],
    searchTerm: "I am"
  },
  "subject_pronouns": {
    summary: "Use subject pronouns to avoid repeating names and to show who does the action.",
    pattern: "I / you / he / she / it / we / they + verb",
    examples: [
      "Maria is a singer. She sings every day.",
      "The song is new. It sounds great.",
      "My friends and I study English. We practice together."
    ],
    commonMistakes: [
      "Use it for one thing or animal when the sex is not important.",
      "Do not repeat the name and pronoun together: 'Maria she sings' is not standard."
    ],
    searchTerm: "she"
  },
  "possessive_adjectives": {
    summary: "Use possessive adjectives before nouns to show who something belongs to.",
    pattern: "my / your / his / her / its / our / their + noun",
    examples: [
      "This is my notebook.",
      "Her favorite song is on the radio.",
      "Their teacher speaks slowly."
    ],
    commonMistakes: [
      "Do not use possessive adjectives alone: say 'my phone', not only 'my'.",
      "His is for a man or boy; her is for a woman or girl."
    ],
    searchTerm: "my"
  },
  "articles": {
    summary: "Use a or an for one non-specific thing, and the when both speaker and listener know which thing.",
    pattern: "a/an + singular noun | the + known noun",
    examples: [
      "I heard a song.",
      "The song was beautiful.",
      "She is an artist."
    ],
    commonMistakes: [
      "Use an before vowel sounds: an old song, an hour.",
      "Do not use a with plural nouns: songs, not a songs."
    ],
    searchTerm: "a song"
  },
  "there_is_there_are": {
    summary: "Use there is and there are to say that something exists or is present.",
    pattern: "there is + singular | there are + plural",
    examples: [
      "There is a guitar in the room.",
      "There are three people on stage.",
      "Is there any water?"
    ],
    commonMistakes: [
      "Use there are with plural nouns.",
      "For questions, invert: Is there...? Are there...?"
    ],
    searchTerm: "there is"
  },
  "present_simple": {
    summary: "Use present simple for routines, facts, likes, dislikes and things that happen regularly.",
    pattern: "subject + verb(s) + object",
    examples: [
      "I listen to music every day.",
      "She studies English after work.",
      "They do not watch videos at night."
    ],
    commonMistakes: [
      "Add -s with he, she and it: she studies.",
      "For negatives and questions, use do or does."
    ],
    searchTerm: "every day"
  },
  "can_cant": {
    summary: "Use can and can't to talk about ability, possibility and permission in simple situations.",
    pattern: "subject + can/can't + base verb",
    examples: [
      "I can understand slow songs.",
      "She can't come today.",
      "Can you repeat that?"
    ],
    commonMistakes: [
      "Use the base verb after can: can go, not can goes.",
      "Can does not change with he, she or it."
    ],
    searchTerm: "can you"
  },
  "past_simple": {
    summary: "Use past simple for actions that started and finished in the past.",
    pattern: "subject + past verb + time/context",
    examples: [
      "I watched a video yesterday.",
      "She went home after class.",
      "They did not like the song."
    ],
    commonMistakes: [
      "After did not, use the base verb: did not go.",
      "Learn common irregular verbs: go/went, hear/heard, make/made."
    ],
    searchTerm: "yesterday"
  },
  "present_continuous": {
    summary: "Use present continuous for actions happening now or temporary situations around now.",
    pattern: "am/is/are + verb-ing",
    examples: [
      "I am listening to a podcast.",
      "She is studying for an exam.",
      "They are staying with friends this week."
    ],
    commonMistakes: [
      "Do not forget be: say 'is studying', not only 'studying'.",
      "Use present simple, not continuous, for regular routines."
    ],
    searchTerm: "is studying"
  },
  "present_simple_vs_present_continuous": {
    summary: "Choose present simple for habits and facts, and present continuous for actions happening now or temporary situations.",
    pattern: "habit/fact -> present simple | now/temporary -> present continuous",
    examples: [
      "I work every morning.",
      "I am working right now.",
      "She usually sings pop, but today she is singing jazz."
    ],
    commonMistakes: [
      "Do not use continuous only because the sentence feels active.",
      "Look for time clues: usually, every day, now, this week."
    ],
    searchTerm: "right now"
  },
  "comparatives_and_superlatives": {
    summary: "Use comparatives to compare two things and superlatives to compare one thing with a whole group.",
    pattern: "adjective-er / more adjective | the adjective-est / the most adjective",
    examples: [
      "This song is slower than the first one.",
      "English is more difficult when people speak fast.",
      "That was the best example."
    ],
    commonMistakes: [
      "Do not combine more with -er: say 'more interesting', not 'more interestinger'.",
      "Use than after comparatives."
    ],
    searchTerm: "better than"
  },
  "some_any": {
    summary: "Use some mostly in positive sentences and any mostly in questions and negatives.",
    pattern: "some + noun | any + noun",
    examples: [
      "I have some questions.",
      "Do you have any time?",
      "There isn't any milk."
    ],
    commonMistakes: [
      "Any is common in negatives and questions.",
      "Some can appear in offers and requests: Would you like some tea?"
    ],
    searchTerm: "some questions"
  },
  "much_many_a_lot_of": {
    summary: "Use much with uncountable nouns, many with plural countable nouns, and a lot of in everyday speech.",
    pattern: "much + uncountable | many + plural | a lot of + both",
    examples: [
      "I don't have much time.",
      "She knows many songs.",
      "We made a lot of progress."
    ],
    commonMistakes: [
      "Use many with countable plurals.",
      "A lot of is natural in positive everyday sentences."
    ],
    searchTerm: "a lot of"
  },
  "should_must_have_to": {
    summary: "Use should for advice, must for strong obligation or certainty, and have to for rules or external obligations.",
    pattern: "should/must/have to + base verb",
    examples: [
      "You should listen again.",
      "I have to finish my homework.",
      "You must be tired."
    ],
    commonMistakes: [
      "Use the base verb after modals: should go, not should goes.",
      "Must and have to can feel different depending on who creates the obligation."
    ],
    searchTerm: "should"
  },
  "passive_voice": {
    summary: "Use passive voice when the action or result matters more than who did the action.",
    pattern: "be + past participle",
    examples: [
      "The song was written in 2020.",
      "English is spoken in many countries.",
      "The video has been watched millions of times."
    ],
    commonMistakes: [
      "Forgetting be: say 'was written', not only 'written'.",
      "Using by when the agent is not important."
    ]
  },
  "reported_speech": {
    summary: "Use reported speech to tell someone what another person said without quoting exact words.",
    pattern: "said/told + that + shifted clause",
    examples: [
      "She said she was tired.",
      "He told me he liked the song.",
      "They said they would call later."
    ],
    commonMistakes: [
      "Using told without an object: say 'told me', not only 'told'.",
      "Forgetting natural tense shifts in past reporting."
    ]
  },
  "present_perfect": {
    summary: "Use present perfect when a past action connects to now, or when the exact time is not the focus.",
    pattern: "have/has + past participle",
    examples: [
      "I have learned five new words.",
      "She has never been to London.",
      "They have just arrived."
    ],
    commonMistakes: [
      "Using present perfect with a finished time like yesterday.",
      "Forgetting has with he, she and it."
    ]
  },
  "key_word_transformations": {
    summary: "A Cambridge-style task where the meaning must stay the same while the sentence changes form.",
    pattern: "original sentence + key word + transformed sentence",
    examples: [
      "Original: I started learning English two years ago.",
      "Key word: FOR",
      "Answer: I have been learning English for two years."
    ],
    commonMistakes: [
      "Changing the meaning instead of only changing the form.",
      "Ignoring the required key word."
    ]
  }
};

const custom = { ...baseCustom, ...pdfGuideCustom };

function slugify(value) {
  return value
    .toLowerCase()
    .replace(/can't/g, "cant")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function cefrOrder(level) {
  return ["Pre-A1", "A1", "A2", "B1", "B2", "C1", "C2", "All"].indexOf(level);
}

function defaultPattern(category, title) {
  if (category === "grammar") return `notice -> understand -> produce: ${title}`;
  if (category === "use_of_english") return `input -> transformation -> same meaning`;
  if (category === "listening") return `first listen: gist -> second listen: detail -> review`;
  if (category === "speaking") return `model -> repeat -> produce -> compare`;
  if (category === "writing") return `plan -> write -> feedback -> rewrite`;
  if (category === "vocabulary") return `meaning -> example -> collocation -> production`;
  return `recognize -> understand -> use`;
}

function optionSet(answer, distractors) {
  const seen = new Set();
  return [answer, ...distractors]
    .filter(Boolean)
    .filter((item) => {
      const key = item.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .slice(0, 4);
}

function firstExampleSentence(override, title) {
  const example = override.examples?.[0];
  if (example && !example.startsWith("Example ")) return example;
  return `I can use ${title.toLowerCase()} in a real sentence.`;
}

function searchTermFor(title, override) {
  if (override.searchTerm) return override.searchTerm;
  const words = title
    .toLowerCase()
    .replace(/can't/g, "can")
    .replace(/[^a-z\s]/g, " ")
    .split(/\s+/)
    .filter((word) => word.length > 2 && !["and", "the", "with", "for", "from", "into", "using"].includes(word));
  return words.slice(0, 2).join(" ") || "english";
}

function makeLessonBlocks(plan, title, override) {
  if (Array.isArray(override.lessonBlocks) && override.lessonBlocks.length > 0) {
    return override.lessonBlocks;
  }

  const meta = categoryMeta[plan.category];
  const example = firstExampleSentence(override, title);
  return [
    {
      title: "1. Notice it",
      body: `Start by finding ${title.toLowerCase()} in one clear sentence: "${example}"`
    },
    {
      title: "2. Understand the job",
      body: override.summary || `Ask what this language helps you do: ${meta.defaultGoal.toLowerCase()}`
    },
    {
      title: "3. Control the form",
      body: `Use the pattern slowly: ${override.pattern || defaultPattern(plan.category, title)}`
    },
    {
      title: "4. Produce your own",
      body: `Write or say one sentence that is true for you, then check it with LanguageTool or your own review.`
    }
  ];
}

function makePracticeTasks(plan, title, override) {
  if (Array.isArray(override.practiceTasks) && override.practiceTasks.length > 0) {
    return override.practiceTasks;
  }

  const pattern = override.pattern || defaultPattern(plan.category, title);
  const example = firstExampleSentence(override, title);
  const wrongExample = override.commonMistakes?.[0] || `Using ${title.toLowerCase()} without checking meaning or context.`;
  const baseAnswer = "Meaning, form and context";

  return [
    {
      id: "notice",
      kind: "multiple_choice",
      title: "Notice",
      instruction: "Choose what you should notice first.",
      prompt: example,
      options: optionSet(baseAnswer, ["Only the translation", "Only the spelling", "Only the word order"]),
      answer: baseAnswer,
      explanation: `${title} becomes useful when you connect what it means, how it is formed and where it appears.`
    },
    {
      id: "pattern",
      kind: "sentence_builder",
      title: "Build the pattern",
      instruction: "Pick the chunk that best completes the pattern.",
      prompt: pattern,
      options: optionSet(pattern, [
        "random words without context",
        "translation first, grammar later",
        "memorise the title only"
      ]),
      answer: pattern,
      explanation: "Patterns are not rules to recite; they are shortcuts for building sentences."
    },
    {
      id: "mistake",
      kind: "error_fix",
      title: "Fix the mistake",
      instruction: "Choose the safest correction strategy.",
      prompt: wrongExample,
      options: optionSet("Check the form and rewrite the whole sentence.", [
        "Ignore the mistake if the meaning is close.",
        "Translate word by word from Spanish.",
        "Make the sentence longer."
      ]),
      answer: "Check the form and rewrite the whole sentence.",
      explanation: "A short rewrite is usually better than patching one word without checking the full sentence."
    },
    {
      id: "transfer",
      kind: "transformation",
      title: "Transfer",
      instruction: "Choose the best next step after recognizing the topic.",
      prompt: `Now use ${title.toLowerCase()} with a new idea from your life.`,
      options: optionSet("Create a new sentence and compare it with the model.", [
        "Repeat only the same example.",
        "Skip production until the topic is perfect.",
        "Use a harder topic immediately."
      ]),
      answer: "Create a new sentence and compare it with the model.",
      explanation: "Transfer is where the topic starts becoming usable English."
    },
    {
      id: "production",
      kind: "production",
      title: "Your turn",
      instruction: "Write one short sentence. Then run it through the writing checker.",
      prompt: `Use ${title.toLowerCase()} to say something true about music, your routine, your plans or your opinion.`,
      options: [],
      answer: "",
      explanation: "Production can be checked with LanguageTool and reused later in your error bank."
    }
  ];
}

function makeTopic(plan, title, index) {
  const id = slugify(title);
  const meta = categoryMeta[plan.category];
  const override = custom[id] || {};
  const level = plan.level;
  const label = meta.label.toLowerCase();
  const searchTerm = searchTermFor(title, override);

  return {
    id,
    title,
    level,
    levelOrder: cefrOrder(level),
    category: plan.category,
    categoryLabel: meta.label,
    order: index + 1,
    sourceBasis,
    summary: override.summary || `${title} is a ${label} topic for ${level === "All" ? "cross-level practice" : level + " learners"}. It helps learners ${meta.defaultGoal.toLowerCase()}`,
    pattern: override.pattern || defaultPattern(plan.category, title),
    lessonBlocks: makeLessonBlocks(plan, title, override),
    learningObjectives: override.learningObjectives || [
      `Recognize ${title.toLowerCase()} in context.`,
      `Use ${title.toLowerCase()} in a short controlled task.`,
      `Review feedback and notice one improvement point.`
    ],
    examples: override.examples || [
      `Example 1 for ${title}.`,
      `Example 2 for ${title}.`,
      `Your turn: create one sentence or response using ${title.toLowerCase()}.`
    ],
    commonMistakes: override.commonMistakes || [
      `Using ${title.toLowerCase()} mechanically without checking meaning or context.`,
      "Choosing a form that is too easy or too advanced for the communicative goal."
    ],
    practiceIdeas: override.practiceIdeas || [
      meta.practice,
      "Save one useful phrase to the review deck.",
      "Try the same idea again with a different song, sentence or topic."
    ],
    practiceTasks: makePracticeTasks(plan, title, override),
    externalResources: {
      authenticExamples: {
        provider: "Tatoeba",
        query: searchTerm,
        description: "Real English sentences with Spanish translations when available."
      },
      wordBank: {
        provider: "Datamuse",
        query: searchTerm,
        description: "Related words and collocations for vocabulary expansion."
      },
      writingCheck: {
        provider: "LanguageTool",
        description: "Grammar and style feedback for the production task."
      }
    },
    quiz: override.quiz || {
      question: `What should you focus on when practising ${title}?`,
      options: [
        "Meaning, form and context",
        "Only memorising rules",
        "Avoiding examples"
      ],
      answer: "Meaning, form and context",
      explanation: "Locupom topics are designed to connect rules with real use, not only memorisation."
    }
  };
}

const generatedCurriculum = loadJSON(
  path.join(DATA_DIR, "curriculum.generated.json"),
  { generatedAt: null, sources: [], topics: [] }
);
const generatedTopics = Array.isArray(generatedCurriculum.topics) ? generatedCurriculum.topics : [];
const sourceDocuments = Array.isArray(generatedCurriculum.sources) ? generatedCurriculum.sources : [];
const legacyTopics = plans.flatMap((plan) => plan.titles.map((title, index) => makeTopic(plan, title, index)));
const legacyCarryOverTopics = legacyTopics.filter((topic) => topic.level === "All");
const topics = generatedTopics.length > 0
  ? [...generatedTopics, ...legacyCarryOverTopics]
  : legacyTopics;

function publicSourceDocument(source, includeBody = false) {
  const base = {
    id: source.id,
    level: source.level,
    title: source.title,
    fileName: source.fileName,
    pdfPath: source.pdfPath,
    pageCount: source.pageCount,
    topicCount: source.topicCount,
    outline: source.outline
  };

  if (includeBody) {
    base.pages = source.pages;
    base.sections = source.sections;
    base.fullText = source.fullText;
  }

  return base;
}

function normalizeLevel(value) {
  if (!value) return null;
  const compact = value.toLowerCase().replace(/\s+/g, "").replace("_", "-");
  const found = levelMeta.find((level) => level.id === compact || level.label.toLowerCase().replace(/\s+/g, "") === compact);
  return found ? found.label : null;
}

function readingCefrLevel(level) {
  return level === "Pre-A1" ? "A1" : level;
}

function normalizeTopic(value, level) {
  const cleanTopic = value?.trim();
  if (cleanTopic) return cleanTopic.slice(0, 80);
  const choices = readingTopicsByLevel[level] || readingTopicsByLevel.B1;
  return choices[0];
}

function slugifyReading(value) {
  return slugify(value || "reading").slice(0, 72);
}

function readingQuestion(id, question) {
  return {
    id,
    prompt: question.prompt,
    options: question.options,
    answer: question.answer,
    explanation: question.explanation
  };
}

function randomIndex(length) {
  if (length <= 1) return 0;
  return crypto.randomInt(0, length);
}

function chooseReadingSelection(level, topic) {
  const templates = localReadingTemplates[level] || localReadingTemplates.B1;
  const notes = readingVariationNotes[level] || readingVariationNotes.B1;
  const recentKey = `${level}:${topic.toLowerCase()}`;
  const previous = recentReadingSelections.get(recentKey);
  let templateIndex = randomIndex(templates.length);
  let noteIndex = randomIndex(notes.length);

  if (templates.length * notes.length > 1) {
    let guard = 0;
    while (`${templateIndex}:${noteIndex}` === previous && guard < 8) {
      templateIndex = randomIndex(templates.length);
      noteIndex = randomIndex(notes.length);
      guard += 1;
    }
  }

  recentReadingSelections.set(recentKey, `${templateIndex}:${noteIndex}`);

  return {
    template: templates[templateIndex],
    note: notes[noteIndex](topic),
    templateIndex,
    noteIndex
  };
}

function splitParagraphs(text) {
  return text
    .split(/\n\s*\n/)
    .map((paragraph) => paragraph.trim())
    .filter(Boolean);
}

function chooseBridgeParagraph(level, topic, variantSeed) {
  const bridges = readingBridgeParagraphs[level] || readingBridgeParagraphs.B1;
  const bridge = bridges[variantSeed % bridges.length];
  return bridge(topic);
}

function buildReadingContent(templateContent, level, topic, note, variantSeed) {
  const paragraphs = splitParagraphs(templateContent);

  while (paragraphs.length < 2) {
    paragraphs.push(chooseBridgeParagraph(level, topic, variantSeed + paragraphs.length));
  }

  paragraphs.push(note);

  const minimumWords = readingMinimumWords[level] || 0;
  let guard = 0;
  while (minimumWords > 0 && wordCount(paragraphs.join(" ")) < minimumWords && guard < 3) {
    paragraphs.splice(
      Math.max(paragraphs.length - 1, 1),
      0,
      chooseBridgeParagraph(level, topic, variantSeed + paragraphs.length + guard)
    );
    guard += 1;
  }

  return paragraphs.join("\n\n");
}

function wordCount(text) {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

const longReadingFallbackDetails = {
  "Pre-A1": {
    title: "The Small Note",
    protagonist: "Mina",
    helper: "her uncle",
    setting: "a small train station",
    time: "early in the day",
    weather: "the floor was bright with morning sun",
    object: "a small note on a wooden bench",
    ordinaryTask: "a short trip across town",
    conflict: "the note had a name but no address",
    clue: "a blue stamp on the corner",
    discovery: "the note belonged to the station flower seller",
    resolution: "Mina returned the note before the next train arrived",
    finalImage: "the note sat safely beside a vase of yellow flowers"
  },
  A1: {
    title: "The Closed Street",
    protagonist: "Alex",
    helper: "a newspaper seller",
    setting: "a quiet city corner",
    time: "before lunch",
    weather: "light rain made the signs shine",
    object: "a paper sign on a closed street",
    ordinaryTask: "finding a small bookshop",
    conflict: "the normal route was blocked",
    clue: "an arrow drawn beside the sign",
    discovery: "a narrow passage led to the back of the bookshop",
    resolution: "Alex found the shop and helped another visitor find it too",
    finalImage: "the wet sign moved gently in the rain"
  },
  A2: {
    title: "The Market List",
    protagonist: "Irene",
    helper: "a fruit seller",
    setting: "the old market hall",
    time: "on a busy Saturday",
    weather: "warm air carried the smell of bread",
    object: "a shopping list written in green ink",
    ordinaryTask: "buying fruit for dinner",
    conflict: "half the stalls had moved to a temporary street",
    clue: "the list named a stall that was not on the map",
    discovery: "the missing stall had moved behind the bakery",
    resolution: "Irene found everything and brought news of the new layout home",
    finalImage: "the green list rested beside a bowl of oranges"
  },
  B1: {
    title: "The Notice on the Gate",
    protagonist: "Paula",
    helper: "her neighbour Daniel",
    setting: "a shared courtyard",
    time: "late in the afternoon",
    weather: "dry leaves moved against the gate",
    object: "a notice taped to the iron bars",
    ordinaryTask: "taking out the recycling",
    conflict: "the courtyard would be locked unless residents repaired the broken lights",
    clue: "the notice listed an old phone number nobody recognized",
    discovery: "the number belonged to the first residents' committee",
    resolution: "the neighbours found the old repair fund and reopened the courtyard",
    finalImage: "new lights came on above the gate just after sunset"
  },
  B2: {
    title: "The Timetable Error",
    protagonist: "Leon",
    helper: "a bus inspector named Marta",
    setting: "a crowded transfer stop",
    time: "during the evening rush",
    weather: "cold wind pushed paper cups along the pavement",
    object: "a timetable with one line printed twice",
    ordinaryTask: "getting across the city before a meeting",
    conflict: "passengers blamed drivers for delays caused by the printed error",
    clue: "two routes were shown leaving from the same bay at the same minute",
    discovery: "the error had redirected people to the wrong side of the avenue",
    resolution: "the transport office corrected the signs and added a temporary guide",
    finalImage: "the corrected timetable looked boring, which was exactly what people needed"
  },
  C1: {
    title: "The River Under the Square",
    protagonist: "Elena",
    helper: "a surveyor named Bruno",
    setting: "a municipal records office",
    time: "on a bright winter morning",
    weather: "pale sun fell across rolled maps",
    object: "a drainage map with a missing blue line",
    ordinaryTask: "checking old plans for a renovation proposal",
    conflict: "official records ignored a buried stream that still shaped the neighbourhood",
    clue: "several streets curved around a space that no current map explained",
    discovery: "the buried stream matched years of unexplained flooding",
    resolution: "the proposal was rewritten to include the hidden watercourse",
    finalImage: "the blue line returned to the plan like a recovered memory"
  },
  C2: {
    title: "The Sentence Without an Actor",
    protagonist: "Nora",
    helper: "a legal editor named Farid",
    setting: "a committee room with high windows",
    time: "near the end of a long hearing",
    weather: "humid air made the papers curl at the edges",
    object: "a public statement full of passive verbs",
    ordinaryTask: "reviewing the final paragraph before release",
    conflict: "the statement sounded balanced while concealing who had made each decision",
    clue: "every controversial action had been turned into an abstract noun",
    discovery: "the document's grammar was protecting the institution from its own facts",
    resolution: "the paragraph was rewritten with clearer agents and fewer evasions",
    finalImage: "the final sentence was shorter, less elegant, and much harder to misunderstand"
  }
};

function buildLongFallbackParagraphs(spec) {
  return [
    `${spec.time}, ${spec.protagonist} arrived at ${spec.setting}, where ${spec.weather}.`,
    `${spec.protagonist} had come because of ${spec.topic}, but the day immediately became more specific than that broad subject.`,
    `The first thing that drew attention was ${spec.object}. It seemed minor, yet it interrupted the normal order of the place.`,
    `${spec.protagonist} paused before touching it. Some objects are ordinary only until someone asks why they are there.`,
    `${spec.helper} noticed the hesitation and came closer, not with an answer, but with a better question.`,
    `The practical problem was clear: ${spec.conflict}. The less visible problem was deciding which details deserved trust.`,
    `At first, the setting offered too many explanations. Each one sounded possible until it was compared with the actual evidence.`,
    `Then ${spec.protagonist} saw ${spec.clue}. The clue was small, but it made several careless explanations fall apart.`,
    `${spec.helper} suggested checking the surrounding details before deciding anything. That advice slowed the moment down in a useful way.`,
    `They began with the most obvious places and found nothing. The absence mattered because it narrowed the search.`,
    `A passer-by offered a quick story about what had happened. It was confident, tidy, and probably wrong.`,
    `${spec.protagonist} returned to the object and looked at it as part of the place, not as a separate puzzle.`,
    `The topic of ${spec.topic} no longer felt abstract. It had become visible through a bench, a sign, a map, a room, or a sentence.`,
    `A second clue appeared only after the first one had changed the question. This is often how small investigations move forward.`,
    `${spec.helper} compared the new clue with the old one. The connection was not dramatic, but it was stable.`,
    `The room seemed to become quieter around the evidence. Even ordinary noises felt like interruptions.`,
    `${spec.protagonist} made one careful guess, then tested it against what the place itself allowed.`,
    `That guess led to the discovery: ${spec.discovery}. It explained more than the object; it explained why the object had been easy to overlook.`,
    `For a moment, nobody said much. The discovery needed a little silence around it before it could become useful.`,
    `The next task was not to make the story prettier. The next task was to make it accurate.`,
    `${spec.helper} checked the detail again, because a useful answer can still be damaged by careless certainty.`,
    `Other people began to understand what had changed. The facts had not become louder, but they had become better arranged.`,
    `${spec.protagonist} noticed that the solution required practical work as well as interpretation.`,
    `The resolution followed from that work: ${spec.resolution}. It was modest, but it changed what people could do next.`,
    `Afterward, the setting looked almost unchanged. The difference was in what people now knew how to notice.`,
    `The original object no longer seemed random. It had become a record of a pressure, a habit, or a forgotten decision.`,
    `That was the strongest part of the day: nothing magical had happened, yet the ordinary world had become less flat.`,
    `${spec.protagonist} left with a clearer sense of how small evidence can alter a larger story.`,
    `${spec.helper} returned to routine work, but even routine work now carried a trace of the discovery.`,
    `The topic remained open, as real topics usually do. One resolved detail had revealed several better questions.`,
    `By the end, ${spec.finalImage}.`,
    `The day had started with ${spec.ordinaryTask}; it ended with a place that could no longer be read in quite the same way.`
  ];
}

function buildLongFallbackQuestions(spec) {
  return [
    readingQuestion("main-idea", {
      prompt: "What is the central problem in the text?",
      options: [
        spec.conflict,
        spec.ordinaryTask,
        spec.finalImage
      ],
      answer: spec.conflict,
      explanation: `The text presents the central problem as: ${spec.conflict}.`
    }),
    readingQuestion("detail", {
      prompt: "Which clue changes the investigation?",
      options: [
        spec.clue,
        spec.weather,
        spec.ordinaryTask
      ],
      answer: spec.clue,
      explanation: `The important clue is ${spec.clue}.`
    }),
    readingQuestion("outcome", {
      prompt: "What is the practical outcome?",
      options: [
        spec.resolution,
        spec.object,
        spec.setting
      ],
      answer: spec.resolution,
      explanation: `The final practical result is that ${spec.resolution}.`
    })
  ];
}

function buildLocalReading({ level, topic, length }) {
  const normalizedLevel = normalizeLevel(level) || "B1";
  const normalizedTopic = normalizeTopic(topic, normalizedLevel);
  const fallback = longReadingFallbackDetails[normalizedLevel] || longReadingFallbackDetails.B1;
  const spec = { ...fallback, topic: normalizedTopic };
  const paragraphs = buildLongFallbackParagraphs(spec);
  const content = paragraphs.join("\n\n");
  const paragraphCount = splitParagraphs(content).length;
  const displayTopic = normalizedTopic.charAt(0).toUpperCase() + normalizedTopic.slice(1);
  const title = `${displayTopic}: ${fallback.title}`;
  const variantId = `long-${paragraphCount}`;

  return {
    id: `${normalizedLevel.toLowerCase().replace(/[^a-z0-9]+/g, "-")}-${slugifyReading(normalizedTopic)}-${length || "standard"}-${variantId}`,
    title,
    level: normalizedLevel,
    cefrLevel: readingCefrLevel(normalizedLevel),
    topic: normalizedTopic,
    estimatedMinutes: Math.max(12, Math.ceil(wordCount(content) / 130)),
    source: "Locupom free long reading library",
    provider: "locupom-free",
    variant: variantId,
    wordCount: wordCount(content),
    paragraphCount,
    summary: `A long original reading about ${normalizedTopic}, with ${paragraphCount} paragraphs.`,
    content,
    questions: buildLongFallbackQuestions(spec)
  };
}

function normalizeMorningBriefReading(item) {
  const content = Array.isArray(item.paragraphs) ? item.paragraphs.join("\n\n") : item.content || "";
  return {
    id: item.id,
    title: item.title,
    level: item.level,
    cefrLevel: readingCefrLevel(item.level),
    topic: item.topic,
    estimatedMinutes: item.estimatedMinutes,
    source: item.source || "Locupom weekday morning brief",
    provider: "locupom-morning-brief",
    variant: morningBriefContent.runId || "morning-brief",
    wordCount: wordCount(content),
    paragraphCount: splitParagraphs(content).length,
    summary: item.summary,
    content,
    questions: item.questions || []
  };
}

function normalizeVocabularyItem(item, index) {
  const id = item.id || `vocab-${slugify(item.word || item.term || String(index + 1))}`;
  return {
    id,
    level: item.level || "All",
    ...item
  };
}

function normalizeExerciseItem(item, index) {
  const id = item.id || `exercise-${slugify(item.title || item.prompt || String(index + 1))}`;
  return {
    id,
    skill: inferExerciseSkill(item),
    ...item
  };
}

function inferExerciseSkill(item) {
  if (item.skill) return item.skill;
  const type = String(item.type || "").toLowerCase();
  if (["translation", "free_translation"].includes(type)) return "translation";
  if (["writing", "writing_prompt", "analysis", "argument_improvement", "style_analysis"].includes(type)) return "writing";
  if (["listening", "cloze_listening"].includes(type)) return "listening";
  if (["grammar", "gap_fill", "multiple_choice"].includes(type)) return "grammar";
  if (["ordering", "sentence_order", "sentence_builder"].includes(type)) return "sentence_builder";
  return "practice";
}

function matchesRequestedLevel(item, searchParams) {
  const level = normalizeLevel(searchParams.get("level"));
  return !level || item.level === level || item.level === "All";
}

function matchesRequestedSkill(item, searchParams) {
  const skill = searchParams.get("skill") || searchParams.get("module");
  return !skill || item.skill === skill;
}

function morningBriefCollectionTotal(kind, searchParams) {
  return (morningBriefContent[kind] || [])
    .map((item, index) => {
      if (kind === "vocabulary") return normalizeVocabularyItem(item, index);
      if (kind === "exercises") return normalizeExerciseItem(item, index);
      return item;
    })
    .filter((item) => matchesRequestedLevel(item, searchParams))
    .filter((item) => kind !== "exercises" || matchesRequestedSkill(item, searchParams))
    .length;
}

function morningBriefItems(kind, searchParams, filter) {
  const collection = morningBriefContent[kind] || [];
  const progressKind = {
    readings: "reading",
    exercises: "exercise",
    speakingPrompts: "speaking",
    vocabulary: "vocabulary"
  }[kind] || "item";
  const normalized = kind === "readings"
    ? collection.map(normalizeMorningBriefReading)
    : kind === "vocabulary"
      ? collection.map(normalizeVocabularyItem)
      : kind === "exercises"
        ? collection.map(normalizeExerciseItem)
        : collection;

  return filterIncompleteItems(
    normalized
      .filter((item) => matchesRequestedLevel(item, searchParams))
      .filter((item) => kind !== "exercises" || matchesRequestedSkill(item, searchParams)),
    progressKind,
    filter
  );
}

function morningBriefReading(searchParams, filter) {
  const level = normalizeLevel(searchParams.get("level")) || "B1";
  const topic = searchParams.get("topic")?.trim().toLowerCase();
  const candidates = (morningBriefContent.readings || [])
    .filter((item) => item.level === level)
    .filter((item) => !topic || item.topic?.toLowerCase().includes(topic))
    .map(normalizeMorningBriefReading);

  if (candidates.length === 0) return null;

  return candidates.find((item) => !isCompletedItem(item, "reading", filter)) || null;
}

function libraryReadingTopics(level, requestedTopic) {
  if (requestedTopic?.trim()) return [normalizeTopic(requestedTopic, level)];
  return readingTopicsByLevel[level] || readingTopicsByLevel.B1;
}

function buildIncompleteLibraryReading(searchParams, filter) {
  const level = normalizeLevel(searchParams.get("level")) || "B1";
  const length = searchParams.get("length") || "standard";
  const requestedTopic = searchParams.get("topic");
  const topicsToTry = libraryReadingTopics(level, requestedTopic);

  for (const topic of topicsToTry) {
    const reading = buildLocalReading({ level, topic, length });
    if (!isCompletedItem(reading, "reading", filter)) {
      return reading;
    }
  }

  return null;
}

async function getLevelledReading(searchParams, filter = completionFilterFor(searchParams)) {
  const briefReading = morningBriefReading(searchParams, filter);
  if (briefReading && searchParams.get("fallback") !== "library") {
    return {
      provider: "locupom-morning-brief",
      providerConfigured: true,
      cost: "free",
      reading: briefReading,
      progress: progressResponse(filter, 1, 1)
    };
  }

  const level = normalizeLevel(searchParams.get("level")) || "B1";
  const reading = buildIncompleteLibraryReading(searchParams, filter);

  return {
    provider: "locupom-free",
    providerConfigured: true,
    cost: "free",
    reading,
    level,
    completed: !reading && filter.shouldExclude,
    message: !reading && filter.shouldExclude ? "No incomplete reading is available for this request." : undefined,
    progress: progressResponse(filter, libraryReadingTopics(level, searchParams.get("topic")).length, reading ? 1 : 0)
  };
}

function send(res, status, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    ...CORS_HEADERS,
    "Cache-Control": "no-store"
  });
  res.end(body);
}

function sendHTML(res, status, body) {
  res.writeHead(status, {
    "Content-Type": "text/html; charset=utf-8",
    ...CORS_HEADERS,
    "Cache-Control": "no-store"
  });
  res.end(body);
}

function sendFile(res, status, filePath, contentType) {
  fs.readFile(filePath, (error, data) => {
    if (error) return notFound(res, "File not found");
    res.writeHead(status, {
      "Content-Type": contentType,
      ...CORS_HEADERS,
      "Cache-Control": "no-store"
    });
    res.end(data);
  });
}

function notFound(res, message = "Not found") {
  send(res, 404, { error: message });
}

function handler(req, res) {
  return Promise.resolve(route(req, res)).catch((error) => {
    if (!res.headersSent) {
      res.writeHead(error.statusCode || 500, {
        "Content-Type": "application/json; charset=utf-8",
        ...CORS_HEADERS,
        "Cache-Control": "no-store"
      });
    }

    res.end(JSON.stringify({ error: error.message || "Unexpected server error" }));
  });
}

function listTopicsBase(searchParams) {
  const level = normalizeLevel(searchParams.get("level"));
  const category = searchParams.get("category");
  const q = searchParams.get("q")?.trim().toLowerCase();
  const includeAll = searchParams.get("includeAll") === "true";

  return topics
    .filter((topic) => !level || topic.level === level || (includeAll && topic.level === "All"))
    .filter((topic) => !category || topic.category === category)
    .filter((topic) => !q || [
      topic.title,
      topic.summary,
      topic.category,
      topic.level,
      topic.source?.fullText
    ].join(" ").toLowerCase().includes(q))
    .sort((a, b) => a.levelOrder - b.levelOrder || a.category.localeCompare(b.category) || a.order - b.order);
}

function listTopics(searchParams, filter = completionFilterFor(searchParams)) {
  return filterIncompleteItems(listTopicsBase(searchParams), "topic", filter);
}

function groupRoadmap(levelLabel, filter = completionFilterFor(new URLSearchParams())) {
  const selected = filterIncompleteItems(
    topics.filter((topic) => topic.level === levelLabel || topic.level === "All"),
    "topic",
    filter
  );
  const grouped = {};

  for (const topic of selected) {
    grouped[topic.category] ||= {
      category: topic.category,
      label: topic.categoryLabel,
      topics: []
    };
    grouped[topic.category].topics.push(topic);
  }

  return Object.values(grouped);
}

function progressPayload(learnerId) {
  const completedItems = completedEntriesForLearner(learnerId)
    .sort((first, second) => String(second.completedAt).localeCompare(String(first.completedAt)));

  return {
    learnerId,
    completedCount: completedItems.length,
    completedKeys: completedItems.map((item) => item.key),
    completedItems
  };
}

async function markCompleted(req, searchParams) {
  const body = await readJSONBody(req);
  const learnerId = requireLearnerId(body.learnerId || searchParams.get("learnerId") || body.userId || body.deviceId);
  const completion = normalizeCompletionPayload(body);
  const now = new Date().toISOString();
  const store = loadProgressStore();
  const learner = learnerProgress(store, learnerId);
  const existing = learner.completed[completion.key];

  learner.completed[completion.key] = {
    ...existing,
    ...completion,
    completedAt: existing?.completedAt || now,
    updatedAt: now
  };
  learner.updatedAt = now;
  saveProgressStore(store);

  return {
    learnerId,
    completed: publicCompletionRecord(learner.completed[completion.key]),
    completedCount: Object.keys(learner.completed).length
  };
}

async function unmarkCompleted(req, searchParams) {
  const body = req.method === "DELETE" ? await readJSONBody(req) : {};
  const learnerId = requireLearnerId(body.learnerId || searchParams.get("learnerId") || body.userId || body.deviceId);
  const completion = normalizeCompletionPayload({
    ...Object.fromEntries(searchParams.entries()),
    ...body
  });
  const store = loadProgressStore();
  const learner = learnerProgress(store, learnerId);
  const removed = Boolean(learner.completed[completion.key]);

  delete learner.completed[completion.key];
  learner.updatedAt = new Date().toISOString();
  saveProgressStore(store);

  return {
    learnerId,
    removed,
    key: completion.key,
    completedCount: Object.keys(learner.completed).length
  };
}

async function route(req, res) {
  if (req.method === "OPTIONS") return send(res, 204, {});

  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  const pathname = url.pathname.replace(/\/+$/, "") || "/";
  const progressFilter = completionFilterFor(url.searchParams);

  if (pathname === "/progress" || pathname === "/progress/completed") {
    if (req.method === "GET") {
      const learnerId = requireLearnerId(url.searchParams.get("learnerId") || url.searchParams.get("userId") || url.searchParams.get("deviceId"));
      return send(res, 200, progressPayload(learnerId));
    }

    if (req.method === "POST") {
      return send(res, 201, await markCompleted(req, url.searchParams));
    }

    if (req.method === "DELETE") {
      return send(res, 200, await unmarkCompleted(req, url.searchParams));
    }

    return send(res, 405, { error: "Use GET, POST or DELETE for progress endpoints." });
  }

  if (req.method !== "GET") return send(res, 405, { error: "Only GET is supported for this endpoint." });

  if (pathname === "/") {
    return sendHTML(res, 200, `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Locupom Topics API</title>
  <style>
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f4f7ff; color: #080f3d; }
    main { max-width: 760px; margin: 64px auto; padding: 0 24px; }
    .card { background: white; border-radius: 24px; padding: 32px; box-shadow: 0 20px 60px rgba(45, 78, 255, .14); }
    h1 { margin: 0 0 8px; font-size: clamp(36px, 8vw, 64px); line-height: 1; }
    p { color: #667096; font-size: 20px; line-height: 1.45; }
    a { display: inline-block; margin: 8px 12px 0 0; color: white; background: #3867ff; padding: 12px 16px; border-radius: 14px; text-decoration: none; font-weight: 700; }
    code { background: #eef2ff; border-radius: 8px; padding: 3px 6px; }
  </style>
</head>
<body>
  <main class="card">
    <h1>Locupom Topics API</h1>
    <p>Status: <strong>running</strong>. Serving <strong>${topics.length}</strong> learning topics from <strong>${sourceDocuments.length}</strong> PDF guides.</p>
    <p>Useful endpoints: <code>/health</code>, <code>/sources</code>, <code>/topics?level=A1</code>, <code>/readings?level=B1</code>, <code>/roadmap?level=B1</code>.</p>
    <a href="/health">Health</a>
    <a href="/sources">PDF Sources</a>
    <a href="/topics?level=A1">A1 Topics</a>
    <a href="/readings?level=B1">B1 Reading</a>
    <a href="/roadmap?level=B1">B1 Roadmap</a>
  </main>
</body>
</html>`);
  }

  if (pathname === "/health") {
    return send(res, 200, {
      name: "Locupom Topics API",
      status: "ok",
      topicCount: topics.length,
      sourceCount: sourceDocuments.length,
      generatedAt: generatedCurriculum.generatedAt,
      pdfBacked: generatedTopics.length > 0,
      endpoints: [
        "/levels",
        "/categories",
        "/sources",
        "/sources/:id",
        "/sources/:id/pdf",
        "/topics",
        "/topics/:id",
        "/topics/:id/source",
        "/readings?level=B1&topic=music",
        "/morning-brief",
        "/speaking?level=B1",
        "/exercises?level=B1",
        "/vocabulary",
        "/progress?learnerId=device-123",
        "POST /progress/completed",
        "/roadmap?level=B1",
        "/search?q=passive"
      ]
    });
  }

  if (pathname === "/levels") return send(res, 200, { levels: levelMeta });
  if (pathname === "/categories") return send(res, 200, { categories: categoryMeta });
  if (pathname === "/sources") {
    return send(res, 200, {
      generatedAt: generatedCurriculum.generatedAt,
      count: sourceDocuments.length,
      sources: sourceDocuments.map((source) => publicSourceDocument(source))
    });
  }

  if (pathname.startsWith("/sources/")) {
    const parts = pathname.split("/").filter(Boolean);
    const id = decodeURIComponent(parts[1] || "");
    const source = sourceDocuments.find((item) => item.id === id);
    if (!source) return notFound(res, `Unknown source id: ${id}`);

    if (parts[2] === "pdf") {
      return sendFile(res, 200, path.join(PDF_DIR, source.fileName), "application/pdf");
    }

    return send(res, 200, publicSourceDocument(source, true));
  }

  if (pathname.startsWith("/pdfs/")) {
    const fileName = decodeURIComponent(pathname.split("/").pop() || "");
    const safeFileName = path.basename(fileName);
    if (safeFileName !== fileName) return notFound(res, "Invalid PDF path");
    return sendFile(res, 200, path.join(PDF_DIR, safeFileName), "application/pdf");
  }

  if (pathname === "/topics") {
    const total = listTopicsBase(url.searchParams).length;
    const result = listTopics(url.searchParams, progressFilter);
    return send(res, 200, {
      count: result.length,
      topics: result,
      progress: progressResponse(progressFilter, total, result.length)
    });
  }

  if (pathname === "/readings") {
    return send(res, 200, await getLevelledReading(url.searchParams, progressFilter));
  }

  if (pathname === "/morning-brief") {
    const readings = morningBriefItems("readings", url.searchParams, progressFilter);
    const speakingPrompts = morningBriefItems("speakingPrompts", url.searchParams, progressFilter);
    const exercises = morningBriefItems("exercises", url.searchParams, progressFilter);
    const vocabulary = morningBriefItems("vocabulary", url.searchParams, progressFilter);
    const total =
      morningBriefCollectionTotal("readings", url.searchParams)
      + morningBriefCollectionTotal("speakingPrompts", url.searchParams)
      + morningBriefCollectionTotal("exercises", url.searchParams)
      + morningBriefCollectionTotal("vocabulary", url.searchParams);
    const visible = readings.length + speakingPrompts.length + exercises.length + vocabulary.length;

    return send(res, 200, {
      generatedAt: morningBriefContent.generatedAt,
      runId: morningBriefContent.runId,
      metadata: morningBriefContent.metadata || {},
      counts: {
        readings: readings.length,
        speakingPrompts: speakingPrompts.length,
        exercises: exercises.length,
        vocabulary: vocabulary.length
      },
      progress: progressResponse(progressFilter, total, visible),
      readings,
      speakingPrompts,
      exercises,
      vocabulary
    });
  }

  if (pathname === "/speaking") {
    const total = morningBriefCollectionTotal("speakingPrompts", url.searchParams);
    const items = morningBriefItems("speakingPrompts", url.searchParams, progressFilter);
    return send(res, 200, {
      generatedAt: morningBriefContent.generatedAt,
      count: items.length,
      progress: progressResponse(progressFilter, total, items.length),
      speakingPrompts: items
    });
  }

  if (pathname === "/exercises") {
    const total = morningBriefCollectionTotal("exercises", url.searchParams);
    const items = morningBriefItems("exercises", url.searchParams, progressFilter);
    return send(res, 200, {
      generatedAt: morningBriefContent.generatedAt,
      count: items.length,
      progress: progressResponse(progressFilter, total, items.length),
      exercises: items
    });
  }

  if (pathname === "/vocabulary") {
    const vocabulary = morningBriefItems("vocabulary", url.searchParams, progressFilter);
    return send(res, 200, {
      generatedAt: morningBriefContent.generatedAt,
      count: vocabulary.length,
      progress: progressResponse(progressFilter, morningBriefCollectionTotal("vocabulary", url.searchParams), vocabulary.length),
      vocabulary
    });
  }

  if (pathname.startsWith("/topics/")) {
    const parts = pathname.split("/").filter(Boolean);
    const id = decodeURIComponent(parts[1] || "");
    const topic = topics.find((item) => item.id === id);
    if (!topic) return notFound(res, `Unknown topic id: ${id}`);
    if (parts[2] === "source") {
      return send(res, 200, topic.source || { error: "No PDF source attached to this topic" });
    }
    return send(res, 200, topic);
  }

  if (pathname === "/roadmap") {
    const level = normalizeLevel(url.searchParams.get("level")) || "B1";
    const total = topics.filter((topic) => topic.level === level || topic.level === "All").length;
    const roadmap = groupRoadmap(level, progressFilter);
    const visible = roadmap.reduce((count, group) => count + group.topics.length, 0);
    return send(res, 200, {
      level,
      progress: progressResponse(progressFilter, total, visible),
      roadmap
    });
  }

  if (pathname === "/search") {
    const total = listTopicsBase(url.searchParams).length;
    const result = listTopics(url.searchParams, progressFilter);
    return send(res, 200, {
      count: result.length,
      topics: result,
      progress: progressResponse(progressFilter, total, result.length)
    });
  }

  return notFound(res);
}

if (require.main === module) {
  http.createServer(handler).listen(PORT, () => {
    console.log(`Locupom Topics API running at http://localhost:${PORT}`);
  });
}

handler.topics = topics;
handler.sourceDocuments = sourceDocuments;
handler.generatedCurriculum = generatedCurriculum;
handler.levelMeta = levelMeta;
handler.categoryMeta = categoryMeta;
handler.route = route;

module.exports = handler;
