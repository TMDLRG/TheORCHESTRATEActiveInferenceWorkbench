# SSML Prosody Guide for Claude Voice Connector

## CRITICAL: Always Use SSML for Natural Speech

When speaking text aloud, **ALWAYS wrap your content in SSML tags** to ensure natural, 
human-like prosody. Raw text without SSML sounds robotic and choppy.

## Default Voice Profile

**Voice:** `en-AU-FreyaNeural` (Australian English, Female)
**Base Rate:** `-5%` (slightly slower for clarity)
**Natural Pauses:** Add `<break>` tags at punctuation and thought boundaries

## Basic SSML Structure

```xml
<speak>
  <prosody rate="-5%" pitch="+0%">
    Your content here with <break time="300ms"/> natural pauses.
  </prosody>
</speak>
```

## Prosody Controls

### Rate (Speaking Speed)
- `x-slow` - Very slow, for emphasis or difficult content
- `slow` - Slow, for clarity
- `medium` - Normal speed
- `fast` - Quick, for excitement or lists
- `x-fast` - Very fast
- Percentages: `-20%`, `+10%`, etc.

### Pitch
- `x-low`, `low`, `medium`, `high`, `x-high`
- Hertz adjustments: `-2Hz`, `+5Hz`
- Percentages: `-10%`, `+15%`

### Volume
- `silent`, `x-soft`, `soft`, `medium`, `loud`, `x-loud`
- Percentages: `-20%`, `+30%`

## Break Tags (ESSENTIAL for Natural Flow)

Use breaks to create natural pauses:

```xml
<break time="200ms"/>  <!-- Short pause - between clauses -->
<break time="400ms"/>  <!-- Medium pause - between sentences -->
<break time="600ms"/>  <!-- Long pause - between paragraphs/topics -->
<break time="1s"/>     <!-- Dramatic pause -->

### When to Insert Breaks
- After periods: 300-400ms
- After commas: 150-200ms  
- After colons/semicolons: 250-300ms
- Before important words: 200ms
- Between list items: 200ms
- Topic transitions: 500-800ms

## Emphasis

```xml
<emphasis level="strong">This is important!</emphasis>
<emphasis level="moderate">This is notable.</emphasis>
<emphasis level="reduced">This is parenthetical.</emphasis>
```

## Say-As (Pronunciation Control)

```xml
<say-as interpret-as="cardinal">42</say-as>        <!-- "forty-two" -->
<say-as interpret-as="ordinal">3</say-as>          <!-- "third" -->
<say-as interpret-as="characters">API</say-as>     <!-- "A P I" -->
<say-as interpret-as="date" format="mdy">12/25/2024</say-as>
<say-as interpret-as="time">3:30pm</say-as>
<say-as interpret-as="telephone">+1-555-123-4567</say-as>
```

## Sentence and Paragraph Structure

```xml
<speak>
  <p>
    <s>First sentence of the paragraph.</s>
    <s>Second sentence with natural flow.</s>
  </p>
  <break time="500ms"/>
  <p>
    <s>New paragraph starts here.</s>
  </p>
</speak>
```


## Context-Aware Prosody Patterns

### Conversational/Friendly
```xml
<prosody rate="-5%" pitch="+5%">
  Hey there! <break time="200ms"/> Great to chat with you.
</prosody>
```

### Professional/Informative
```xml
<prosody rate="-10%" pitch="+0%">
  The quarterly results show <break time="150ms"/> 
  a <emphasis level="moderate">fifteen percent</emphasis> increase.
</prosody>
```

### Storytelling/Narrative
```xml
<prosody rate="-15%">
  Once upon a time, <break time="400ms"/> 
  in a land far away, <break time="300ms"/>
  there lived a <emphasis level="strong">curious</emphasis> developer.
</prosody>
```

### Urgent/Alert
```xml
<prosody rate="+10%" pitch="+10%">
  <emphasis level="strong">Warning!</emphasis> <break time="200ms"/>
  The system requires immediate attention.
</prosody>
```

### Lists and Enumeration
```xml
<prosody rate="-5%">
  There are three key points: <break time="300ms"/>
  First, <break time="150ms"/> clarity. <break time="250ms"/>
  Second, <break time="150ms"/> consistency. <break time="250ms"/>
  And third, <break time="150ms"/> context.
</prosody>
```


## Best Practices

1. **Always wrap in `<speak>` tags** - Required for SSML parsing
2. **Use `<prosody>` for base settings** - Set rate/pitch at the outer level
3. **Insert breaks at natural pause points** - Commas, periods, thought boundaries
4. **Match prosody to content emotion** - Excited = faster/higher, serious = slower/lower
5. **Use emphasis sparingly** - Too much emphasis = no emphasis
6. **Test complex SSML** - Build up gradually for long content

## Quick Template

For most speech, use this pattern:

```xml
<speak>
  <prosody rate="-5%" pitch="+0%">
    [Opening statement]. <break time="300ms"/>
    [Main content with <break time="200ms"/> natural pauses]. <break time="400ms"/>
    [Closing thought].
  </prosody>
</speak>
```

## Voice Profiles Reference

| Profile | Voice | Rate | Pitch | Use Case |
|---------|-------|------|-------|----------|
| freya_default | en-AU-FreyaNeural | -5% | +0% | General conversation |
| freya_slow | en-AU-FreyaNeural | -15% | +0% | Complex explanations |
| freya_excited | en-AU-FreyaNeural | +5% | +5% | Enthusiastic content |
| sonia_professional | en-GB-SoniaNeural | -10% | +0% | Business/formal |
