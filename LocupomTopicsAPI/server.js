const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = Number(process.env.PORT || 8787);
const ROOT_DIR = __dirname;
const DATA_DIR = path.join(ROOT_DIR, "data");
const PDF_DIR = path.join(ROOT_DIR, "pdfs");

function loadJSON(filePath, fallback) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return fallback;
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

function send(res, status, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Cache-Control": "no-store"
  });
  res.end(body);
}

function sendHTML(res, status, body) {
  res.writeHead(status, {
    "Content-Type": "text/html; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Cache-Control": "no-store"
  });
  res.end(body);
}

function sendFile(res, status, filePath, contentType) {
  fs.readFile(filePath, (error, data) => {
    if (error) return notFound(res, "File not found");
    res.writeHead(status, {
      "Content-Type": contentType,
      "Access-Control-Allow-Origin": "*",
      "Cache-Control": "no-store"
    });
    res.end(data);
  });
}

function notFound(res, message = "Not found") {
  send(res, 404, { error: message });
}

function listTopics(searchParams) {
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

function groupRoadmap(levelLabel) {
  const selected = topics.filter((topic) => topic.level === levelLabel || topic.level === "All");
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

function route(req, res) {
  if (req.method === "OPTIONS") return send(res, 204, {});
  if (req.method !== "GET") return send(res, 405, { error: "Only GET is supported" });

  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  const pathname = url.pathname.replace(/\/+$/, "") || "/";

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
    <p>Useful endpoints: <code>/health</code>, <code>/sources</code>, <code>/topics?level=A1</code>, <code>/roadmap?level=B1</code>.</p>
    <a href="/health">Health</a>
    <a href="/sources">PDF Sources</a>
    <a href="/topics?level=A1">A1 Topics</a>
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
    const result = listTopics(url.searchParams);
    return send(res, 200, { count: result.length, topics: result });
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
    return send(res, 200, {
      level,
      roadmap: groupRoadmap(level)
    });
  }

  if (pathname === "/search") {
    const result = listTopics(url.searchParams);
    return send(res, 200, { count: result.length, topics: result });
  }

  return notFound(res);
}

if (require.main === module) {
  http.createServer(route).listen(PORT, () => {
    console.log(`Locupom Topics API running at http://localhost:${PORT}`);
  });
}

module.exports = { topics, sourceDocuments, generatedCurriculum, levelMeta, categoryMeta, route };
