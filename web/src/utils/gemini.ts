export interface GeminiWeightResult {
  product_weight_g: number | null;
  package_weight_g: number | null;
}

export async function fetchWeightsFromGemini(productName: string): Promise<GeminiWeightResult> {
  const apiKey =
    localStorage.getItem('gemini_api_key') ||
    (import.meta.env.VITE_GEMINI_API_KEY as string | undefined) ||
    (import.meta.env.GEMINI_API_KEY as string | undefined);

  if (!apiKey || !apiKey.trim()) {
    throw new Error(
      'Gemini API Key is not configured. Please set VITE_GEMINI_API_KEY in your env file or configure it in the UI.',
    );
  }

  if (!productName || !productName.trim()) {
    throw new Error('Please enter a product name first.');
  }

  const prompt = `You are a product specification expert. Given a product name, estimate its typical product weight (net weight of the contents alone, excluding packaging) and package weight (weight of the container/packaging material alone, e.g. bottle, plastic wrap, box) in grams (g).

Product Name: "${productName.trim()}"

Provide your answer in the following JSON format:
{
  "product_weight_g": number (weight in grams, or null if completely unknown),
  "package_weight_g": number (weight in grams, or null if completely unknown)
}

Estimate realistic and standard commercial retail weights if you do not know the exact figures. 
Return ONLY the raw JSON object. Do not include markdown code block backticks (e.g. do not wrap the response in \`\`\`json). Just return the raw JSON string.`;

  // List of candidate model IDs to try, from newest/recommended to fallback versions
  const modelCandidates = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-latest',
  ];

  let lastError: Error | null = null;

  for (const model of modelCandidates) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1/models/${model}:generateContent?key=${apiKey}`;

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: prompt,
                },
              ],
            },
          ],
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        let errMsg = errorText;
        try {
          const parsed = JSON.parse(errorText);
          errMsg = parsed.error?.message || errorText;
        } catch {
          // ignore
        }
        throw new Error(errMsg || response.statusText);
      }

      const data = await response.json();
      const textResponse = data.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!textResponse) {
        throw new Error('No text returned from the model.');
      }

      // Clean up response formatting to extract the JSON payload
      let cleanedText = textResponse.trim();

      // Strip markdown code block wrappers if present
      if (cleanedText.includes('```')) {
        const jsonMatch = cleanedText.match(/```(?:json)?([\s\S]*?)```/);
        if (jsonMatch && jsonMatch[1]) {
          cleanedText = jsonMatch[1].trim();
        }
      }

      // Isolate the outermost JSON curly braces
      const firstBrace = cleanedText.indexOf('{');
      const lastBrace = cleanedText.lastIndexOf('}');
      if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
        cleanedText = cleanedText.substring(firstBrace, lastBrace + 1);
      }

      const result: GeminiWeightResult = JSON.parse(cleanedText);
      return result;
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : String(err);
      console.warn(`Gemini model ${model} failed: ${errMsg}. Trying next candidate...`);
      lastError = err instanceof Error ? err : new Error(errMsg);
    }
  }

  throw new Error(
    lastError?.message ||
      'Failed to fetch weights from Gemini API after trying all candidate models.',
  );
}
