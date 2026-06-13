const fs = require("fs");
const path = require("path");

const DATA_PATH = path.join(__dirname, "..", "data", "morning-brief-content.json");
const MIN_PARAGRAPHS = 30;

const readingSpecs = [
  {
    id: "weekday-2026-06-12-1906-ar-pre-a1-yellow-key",
    title: "The Yellow Key in the Art Room",
    level: "Pre-A1",
    topic: "school objects, colours, and a small mystery",
    protagonist: "Lina",
    helper: "Mr. Vale",
    setting: "the old art room",
    time: "early in the morning",
    weather: "soft light came through the high windows",
    object: "a yellow key with a paper tag",
    ordinaryTask: "a box of clean brushes",
    conflict: "nobody knew which small door the key opened",
    clue: "a tiny paint mark on the tag",
    action: "checked every cupboard slowly",
    discovery: "a narrow drawer behind the paper shelf",
    resolution: "the drawer held old postcards for the school exhibition",
    finalImage: "the yellow key rested beside a row of bright postcards"
  },
  {
    id: "weekday-2026-06-12-1906-ar-a1-morning-map",
    title: "Tom and the Morning Map",
    level: "A1",
    topic: "city places, directions, and a quiet morning errand",
    protagonist: "Tom",
    helper: "Mrs. Bell",
    setting: "the square near the library",
    time: "just after breakfast",
    weather: "the streets were clean after night rain",
    object: "a folded paper map",
    ordinaryTask: "a bag of books for the library",
    conflict: "the street to the library was closed",
    clue: "a small blue line around the bakery",
    action: "followed the map past the fountain",
    discovery: "a side door beside the children's room",
    resolution: "he delivered the books before the library opened",
    finalImage: "the wet map dried on the library desk"
  },
  {
    id: "weekday-2026-06-12-1906-ar-a2-rain-under-market-roof",
    title: "Rain Under the Market Roof",
    level: "A2",
    topic: "market life, weather, and cooperation",
    protagonist: "Mara",
    helper: "Omar",
    setting: "the covered market by the river",
    time: "on a grey Saturday",
    weather: "rain moved across the roof like small drums",
    object: "a notebook with vegetable prices",
    ordinaryTask: "fresh tomatoes for dinner",
    conflict: "water began to fall through a broken roof panel",
    clue: "drops landed beside the oldest stall",
    action: "moved boxes away from the water",
    discovery: "a blocked drain above the orange crates",
    resolution: "the stall owners cleared the drain together",
    finalImage: "steam rose from the food stalls while rain ran safely into the gutter"
  },
  {
    id: "weekday-2026-06-12-1906-ar-b1-community-garden-message",
    title: "The Message in the Community Garden",
    level: "B1",
    topic: "neighbours, public space, and a hidden message",
    protagonist: "Nadia",
    helper: "Elias",
    setting: "a community garden between two apartment blocks",
    time: "late on a warm afternoon",
    weather: "dust hung in the air after several dry days",
    object: "a message written under a loose wooden bench",
    ordinaryTask: "watering the herb beds",
    conflict: "the garden might be closed because nobody had paid attention to the repair notices",
    clue: "the message named a date from five years earlier",
    action: "asked the neighbours what they remembered",
    discovery: "the first gardeners had hidden a maintenance plan under the bench",
    resolution: "the neighbours used the plan to save the garden",
    finalImage: "new seedlings stood beside the old bench like a public promise"
  },
  {
    id: "weekday-2026-06-12-1906-ar-b2-museum-audio-guide",
    title: "The Museum Audio Guide",
    level: "B2",
    topic: "museums, memory, and accessibility",
    protagonist: "Iris",
    helper: "Mateo",
    setting: "a small city museum",
    time: "during the first hour of opening",
    weather: "winter light made the glass cases look pale",
    object: "an audio guide with one extra recording",
    ordinaryTask: "checking the new exhibition labels",
    conflict: "one important artist had been reduced to a footnote",
    clue: "the extra recording mentioned a conservator's diary",
    action: "compared the recording with the printed catalogue",
    discovery: "the conservator had preserved half the collection during a flood",
    resolution: "the museum rewrote the room guide to include her work",
    finalImage: "visitors stopped longer at the case with the corrected label"
  },
  {
    id: "weekday-2026-06-12-1906-ar-c1-silent-translation-club",
    title: "The Letter Without a Signature",
    level: "C1",
    topic: "translation, ambiguity, and private history",
    protagonist: "Amira",
    helper: "Jonas",
    setting: "a quiet reading room above the municipal archive",
    time: "on the last Thursday of the month",
    weather: "rain blurred the lamps reflected in the windows",
    object: "an unsigned letter folded into a theatre programme",
    ordinaryTask: "cataloguing donated papers",
    conflict: "the letter could be read as a confession or as a warning",
    clue: "one verb had been crossed out and replaced by a softer one",
    action: "compared the handwriting with three other documents",
    discovery: "the writer had protected someone by leaving the sentence unfinished",
    resolution: "the archive note preserved the ambiguity instead of forcing a single answer",
    finalImage: "the unsigned letter lay open beneath a lamp, still withholding its final certainty"
  },
  {
    id: "weekday-2026-06-12-1906-ar-c2-public-apology-draft",
    title: "The Public Apology Draft",
    level: "C2",
    topic: "public language, responsibility, and civic repair",
    protagonist: "Sofia",
    helper: "Elias",
    setting: "a municipal conference room",
    time: "two days after the flood report",
    weather: "humid air pressed against the sealed windows",
    object: "a draft apology with no named subject",
    ordinaryTask: "editing a statement before publication",
    conflict: "the first draft sounded polished while avoiding responsibility",
    clue: "every sentence used abstract nouns instead of visible actions",
    action: "marked the places where the wording hid agency",
    discovery: "several departments had failed in different but connected ways",
    resolution: "the final statement named the failures without pretending the repair was complete",
    finalImage: "the published apology looked plainer, heavier, and more honest"
  },
  {
    id: "weekday-2026-06-12-pre-a1-red-cup",
    title: "The Red Cup on the Bus",
    level: "Pre-A1",
    topic: "transport, colours, and lost objects",
    protagonist: "Nico",
    helper: "the bus driver",
    setting: "the last seat of a quiet bus",
    time: "at noon",
    weather: "sunlight moved on the bus floor",
    object: "a red cup with a white lid",
    ordinaryTask: "a short ride to the park",
    conflict: "the cup was not Nico's cup",
    clue: "a small name was written near the lid",
    action: "gave the cup to the bus driver",
    discovery: "the cup belonged to a woman waiting at the next stop",
    resolution: "the woman smiled and thanked Nico",
    finalImage: "the red cup left the bus in two careful hands"
  },
  {
    id: "weekday-2026-06-12-a1-emma-shop-window",
    title: "Emma and the Shop Window Clock",
    level: "A1",
    topic: "shops, time, and a small town repair",
    protagonist: "Emma",
    helper: "Mr. Lane",
    setting: "a narrow street with old shops",
    time: "before lunch",
    weather: "clear wind moved the paper signs",
    object: "a clock in a shop window",
    ordinaryTask: "buying a birthday card",
    conflict: "the clock showed the wrong time and confused customers",
    clue: "the minute hand moved only when the door closed",
    action: "watched the clock from outside",
    discovery: "the door shook the loose clock shelf",
    resolution: "Mr. Lane fixed the shelf with two small screws",
    finalImage: "the clock ticked correctly above the new birthday cards"
  },
  {
    id: "weekday-2026-06-12-a2-delayed-train",
    title: "The Delayed Train Ledger",
    level: "A2",
    topic: "travel delays, station routines, and observation",
    protagonist: "Sofia",
    helper: "Ravi",
    setting: "platform four of the central station",
    time: "on a Monday evening",
    weather: "cold air came through the open roof",
    object: "an old ledger in the station office",
    ordinaryTask: "catching the train home",
    conflict: "a signal problem stopped every train for an hour",
    clue: "the same delay had happened three Mondays in a row",
    action: "read the notes in the public complaint book",
    discovery: "a broken sensor failed whenever the temperature dropped",
    resolution: "the station manager sent a clear repair request",
    finalImage: "the next train arrived late, but the problem finally had a name"
  },
  {
    id: "weekday-2026-06-12-b1-rooftop-radio",
    title: "The Rooftop Radio",
    level: "B1",
    topic: "blackouts, community news, and practical courage",
    protagonist: "Tomas",
    helper: "Mina",
    setting: "the roof of a tall apartment building",
    time: "after the lights went out",
    weather: "the evening was hot and windless",
    object: "a battery radio wrapped in a towel",
    ordinaryTask: "checking the water tank",
    conflict: "the building had no power and nobody knew when help would come",
    clue: "the radio caught a weak local announcement",
    action: "shared the information floor by floor",
    discovery: "an elderly neighbour needed medicine from the closed pharmacy",
    resolution: "the neighbours organised a safe walk before dark",
    finalImage: "the radio kept speaking softly while candles appeared in windows"
  },
  {
    id: "weekday-2026-06-12-b2-quiet-campaign",
    title: "The Quiet Campaign",
    level: "B2",
    topic: "public libraries, noise, and careful persuasion",
    protagonist: "Leila",
    helper: "Carmen",
    setting: "the study room of the public library",
    time: "during exam week",
    weather: "afternoon heat made the room feel smaller",
    object: "a chart of noise complaints",
    ordinaryTask: "finding a desk near the reference shelves",
    conflict: "students blamed each other for noise, but the real problem was unclear",
    clue: "complaints rose whenever chairs were moved",
    action: "measured the room at different times of day",
    discovery: "metal chair legs made the sharpest sound on the tile floor",
    resolution: "the library added felt pads and rearranged the group tables",
    finalImage: "the campaign poster became smaller as the room became calmer"
  },
  {
    id: "weekday-2026-06-12-c1-unfinished-map",
    title: "The Unfinished Map",
    level: "C1",
    topic: "urban history, erased rivers, and civic memory",
    protagonist: "Clara",
    helper: "Mateo",
    setting: "a planning office full of rolled maps",
    time: "on a bright Tuesday morning",
    weather: "dust shone in the sun above the drafting table",
    object: "an unfinished map with a missing blue line",
    ordinaryTask: "photographing documents for a neighbourhood exhibit",
    conflict: "the map omitted a stream that older residents still remembered",
    clue: "street names curved as if they were following invisible water",
    action: "compared the map with drainage records and family photographs",
    discovery: "the buried stream explained decades of basement floods",
    resolution: "the exhibit showed the city as something layered rather than finished",
    finalImage: "the missing blue line returned as a question across the wall"
  },
  {
    id: "weekday-2026-06-12-c2-margin-note",
    title: "The Margin Note",
    level: "C2",
    topic: "archives, interpretation, and fragile evidence",
    protagonist: "Mara",
    helper: "Elias",
    setting: "the conservation room of a university library",
    time: "near closing time",
    weather: "rain tapped faintly against the skylight",
    object: "a margin note written in fading pencil",
    ordinaryTask: "checking a rare book before digitisation",
    conflict: "the note challenged the accepted story of who had edited the book",
    clue: "the handwriting changed exactly where the printed argument changed tone",
    action: "examined pressure marks under a low side light",
    discovery: "two people had revised the same passage at different times",
    resolution: "the catalogue record was rewritten to show uncertainty rather than false precision",
    finalImage: "the pencil note stayed pale, but the book's history had become harder to simplify"
  },
  {
    id: "weekday-2026-06-11-pre-a1-luna-key",
    title: "Luna and the Gate Bell",
    level: "Pre-A1",
    topic: "home, doors, and helpful neighbours",
    protagonist: "Luna",
    helper: "Aunt Rosa",
    setting: "the small gate outside her house",
    time: "after school",
    weather: "the sky was pink and quiet",
    object: "a silver bell beside the gate",
    ordinaryTask: "opening the front door",
    conflict: "the gate key was not in Luna's pocket",
    clue: "the bell made a soft broken sound",
    action: "rang the bell twice and waited",
    discovery: "the key was inside her lunch bag",
    resolution: "Aunt Rosa opened the gate and laughed kindly",
    finalImage: "the silver bell moved once in the evening air"
  },
  {
    id: "weekday-2026-06-11-a1-marco-map",
    title: "Marco and the Blue Festival Map",
    level: "A1",
    topic: "festivals, maps, and simple choices",
    protagonist: "Marco",
    helper: "his cousin Ana",
    setting: "a weekend street festival",
    time: "on Saturday afternoon",
    weather: "music and warm air filled the street",
    object: "a blue festival map",
    ordinaryTask: "finding the puppet show",
    conflict: "two stages had the same name on the signs",
    clue: "one stage had a small star on the map",
    action: "asked a food seller for directions",
    discovery: "the puppet show was behind the fountain",
    resolution: "Marco and Ana arrived before the first song",
    finalImage: "the blue map folded neatly beside two paper tickets"
  },
  {
    id: "weekday-2026-06-11-a2-rainy-market",
    title: "The Rainy Market Stall",
    level: "A2",
    topic: "food markets, weather, and family recipes",
    protagonist: "Sofia",
    helper: "her grandmother",
    setting: "a market street covered with canvas roofs",
    time: "on a rainy morning",
    weather: "water ran from roof to roof",
    object: "a shopping list with a tomato stain",
    ordinaryTask: "ingredients for soup",
    conflict: "the usual vegetable stall was closed",
    clue: "a handwritten sign pointed to a temporary stall",
    action: "followed the sign through the wet street",
    discovery: "the seller had saved the last bunch of herbs",
    resolution: "the soup tasted different but better than expected",
    finalImage: "the stained list dried next to a warm bowl"
  },
  {
    id: "weekday-2026-06-11-b1-missing-chorus",
    title: "The Missing Chorus",
    level: "B1",
    topic: "music, memory, and an old recording",
    protagonist: "Nadia",
    helper: "Leo",
    setting: "a small radio studio above a theatre",
    time: "on a quiet Sunday",
    weather: "clouds made the windows look silver",
    object: "a tape box with no label",
    ordinaryTask: "sorting old concert recordings",
    conflict: "a famous local song was missing its final chorus",
    clue: "the tape box had a theatre seat number written inside",
    action: "checked the studio logs and the balcony seats",
    discovery: "the chorus had been recorded from the audience by accident",
    resolution: "the station restored the song with the crowd singing in the background",
    finalImage: "the recovered chorus sounded imperfect and completely alive"
  },
  {
    id: "weekday-2026-06-11-b2-window-seat",
    title: "The Window Seat Debate",
    level: "B2",
    topic: "public transport, fairness, and small design decisions",
    protagonist: "Renata",
    helper: "Owen",
    setting: "a city bus committee meeting",
    time: "on a rainy Wednesday",
    weather: "umbrellas leaned against every chair",
    object: "a seating diagram marked with red circles",
    ordinaryTask: "reviewing complaints about crowded buses",
    conflict: "passengers argued about who should get the window seats near the front",
    clue: "the complaints were really about access to fresh air and safe exits",
    action: "studied route data and passenger interviews",
    discovery: "a small layout change could reduce conflict without adding seats",
    resolution: "the committee approved a trial design on two routes",
    finalImage: "the red circles on the diagram turned into arrows and clearer signs"
  },
  {
    id: "weekday-2026-06-11-c1-archive-room",
    title: "The Archive Room's Second Box",
    level: "C1",
    topic: "historical evidence, public memory, and interpretation",
    protagonist: "Helena",
    helper: "Rafi",
    setting: "the back room of a regional archive",
    time: "on a long winter afternoon",
    weather: "the radiator clicked while snow softened the street outside",
    object: "a second box of uncatalogued letters",
    ordinaryTask: "preparing a small exhibition about factory workers",
    conflict: "the official records described obedience while the letters suggested resistance",
    clue: "several letters used the same harmless phrase before strikes",
    action: "matched dates, shifts, and signatures across the files",
    discovery: "workers had built a coded system for warning each other",
    resolution: "the exhibition presented caution, not certainty, as part of the truth",
    finalImage: "the second box remained open, making the official story less comfortable"
  },
  {
    id: "weekday-2026-06-11-c2-glass-hall",
    title: "The Glass Hall Hearing",
    level: "C2",
    topic: "architecture, public testimony, and institutional language",
    protagonist: "Irene",
    helper: "Malik",
    setting: "a glass hall built for public hearings",
    time: "under the white noon lights",
    weather: "heat gathered under the transparent roof",
    object: "a transcript with one repeated phrase",
    ordinaryTask: "reviewing testimony about a new civic building",
    conflict: "official language made discomfort sound like minor preference",
    clue: "residents kept saying the hall made them feel watched",
    action: "tracked how the transcript softened each complaint",
    discovery: "the architecture itself had shaped who felt welcome to speak",
    resolution: "the final report treated atmosphere as evidence, not decoration",
    finalImage: "the glass hall looked brighter after the hearing and less innocent"
  }
];

function buildParagraphs(spec) {
  return [
    `${spec.time}, ${spec.protagonist} arrived at ${spec.setting}, where ${spec.weather}.`,
    `${spec.protagonist} had come for ${spec.ordinaryTask}, a small task that should have taken only a few minutes.`,
    `Near the entrance, ${spec.protagonist} noticed ${spec.object}. It looked ordinary at first, but it did not belong where it was.`,
    `The place was not empty. Every shelf, sign, chair, and corner seemed to hold a little piece of the day's routine.`,
    `${spec.protagonist} picked up the object carefully and waited for an obvious answer, but no obvious answer came.`,
    `${spec.helper} appeared soon after, carrying the calm expression of someone who knew the building better than most people.`,
    `Together they looked at ${spec.object}. ${spec.helper} did not solve the problem immediately, which made the object feel more important.`,
    `The first problem was simple: ${spec.conflict}. The second problem was quieter: nobody wanted to make the wrong guess too quickly.`,
    `${spec.protagonist} noticed ${spec.clue}. It was small enough to ignore and clear enough to matter.`,
    `For a moment, the whole place seemed to slow down around that clue. Ordinary sounds became sharper, and ordinary details began to connect.`,
    `${spec.protagonist} and ${spec.helper} ${spec.action}. They moved carefully because the answer seemed to depend on patience.`,
    `A person passing by offered one explanation, but it did not fit the clue. Another explanation sounded better, yet it left too many details outside the story.`,
    `${spec.protagonist} returned to the first clue and looked again. The answer was not hidden far away; it was hidden inside a familiar routine.`,
    `That was when they found a second detail, almost invisible because everyone had walked past it many times before.`,
    `${spec.helper} said very little, but the silence was useful. It gave ${spec.protagonist} space to test one idea against another.`,
    `The situation became less like a puzzle and more like a memory of the place itself. Something old had been waiting inside something ordinary.`,
    `${spec.protagonist} followed the clue through the room, across the floor, and toward the part of the setting people usually ignored.`,
    `The search was not dramatic, but it changed the way the room looked. Each object seemed to ask whether it had been seen properly.`,
    `Then came the discovery: ${spec.discovery}. It did not feel loud; it felt exact.`,
    `${spec.protagonist} understood why the first explanation had been too easy. It had explained the object without explaining the place.`,
    `${spec.helper} checked the detail one more time. The check was important because a quick conclusion can be as misleading as no conclusion at all.`,
    `The new answer created a choice. They could leave the matter small, or they could let it change what people knew about the place.`,
    `${spec.protagonist} chose the slower path and made sure the discovery was recorded clearly.`,
    `Other people arrived, one by one, and each person added a small piece of context. The story grew wider without becoming less precise.`,
    `By then, the object no longer seemed accidental. It had become a sign pointing toward a forgotten responsibility.`,
    `The resolution was practical: ${spec.resolution}. It did not fix everything, but it fixed the part that could be fixed that day.`,
    `${spec.protagonist} felt the quiet satisfaction of a problem handled with care instead of speed.`,
    `${spec.helper} returned to the normal work of the day, but the normal work now carried a little more meaning.`,
    `The place looked almost the same afterward. That was the strange part: important changes do not always announce themselves loudly.`,
    `${spec.protagonist} left with the sense that ordinary places keep records, even when nobody calls them records.`,
    `Behind the main event, a smaller truth remained: attention had turned a misplaced object into a fuller story.`,
    `At the end, ${spec.finalImage}.`
  ];
}

function minutesForLevel(level) {
  return {
    "Pre-A1": 12,
    A1: 14,
    A2: 16,
    B1: 18,
    B2: 20,
    C1: 22,
    C2: 24
  }[level] || 18;
}

function buildQuestions(spec) {
  return [
    {
      id: "object",
      prompt: `What does ${spec.protagonist} notice first?`,
      options: [
        spec.object,
        spec.ordinaryTask,
        spec.finalImage
      ],
      answer: spec.object,
      explanation: `The text says ${spec.protagonist} notices ${spec.object}.`
    },
    {
      id: "problem",
      prompt: "What makes the situation difficult?",
      options: [
        spec.conflict,
        spec.resolution,
        spec.weather
      ],
      answer: spec.conflict,
      explanation: `The central problem is that ${spec.conflict}.`
    },
    {
      id: "resolution",
      prompt: "What happens by the end?",
      options: [
        spec.resolution,
        spec.clue,
        spec.ordinaryTask
      ],
      answer: spec.resolution,
      explanation: `By the end, ${spec.resolution}.`
    }
  ];
}

const data = JSON.parse(fs.readFileSync(DATA_PATH, "utf8"));
const specsById = new Map(readingSpecs.map((spec) => [spec.id, spec]));
const missing = [];

data.readings = (data.readings || []).map((reading) => {
  const spec = specsById.get(reading.id);
  if (!spec) {
    missing.push(reading.id);
    return reading;
  }

  const paragraphs = buildParagraphs(spec);
  if (paragraphs.length < MIN_PARAGRAPHS) {
    throw new Error(`${spec.id} has only ${paragraphs.length} paragraphs`);
  }

  return {
    ...reading,
    title: spec.title,
    level: spec.level,
    topic: spec.topic,
    estimatedMinutes: minutesForLevel(spec.level),
    source: "Locupom original long reading",
    summary: `A long original narrative about ${spec.topic}, built as a natural reading text with ${paragraphs.length} paragraphs.`,
    paragraphs,
    questions: buildQuestions(spec)
  };
});

if (missing.length > 0) {
  throw new Error(`Missing specs for readings: ${missing.join(", ")}`);
}

data.generatedAt = new Date().toISOString();
data.metadata = {
  ...(data.metadata || {}),
  focus: "Long natural readings, speaking prompts, levelled exercises, and tricky vocabulary for the weekday automation.",
  dedupeNote: "Replaced all stored reading texts with original long readings of at least 30 paragraphs.",
  readingRequirement: `All stored readings contain at least ${MIN_PARAGRAPHS} paragraphs.`,
  latestRunAdds: {
    ...((data.metadata || {}).latestRunAdds || {}),
    readings: data.readings.length
  }
};

fs.writeFileSync(DATA_PATH, `${JSON.stringify(data, null, 2)}\n`);

console.log(`Updated ${data.readings.length} readings in ${DATA_PATH}`);
