import express from "express";
import path from "path";
import { createServer as createViteServer } from "vite";
import { GoogleGenAI } from "@google/genai";

const app = express();
const PORT = 3000;

app.use(express.json());

// Initialize Gemini client lazily
function getGeminiClient() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY environment variable is required");
  }
  return new GoogleGenAI({ apiKey });
}

// API endpoint to parse voice commands with AI, correct time confusion, and prioritize tasks
app.post("/api/parse-voice", async (req, res) => {
  try {
    const { transcript, currentDateTime } = req.body;
    
    if (!transcript) {
      return res.status(400).json({ error: "Transcript is required" });
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      // Fallback mock parsing if no API key is set yet
      return res.json({
        title: transcript.slice(0, 40),
        date: new Date().toISOString().split("T")[0],
        time: "14:00",
        priority: "Média",
        category: "Compromisso",
        correctionNote: "",
        spokenConfirmation: `Entendido: ${transcript}. Agendado para hoje.`
      });
    }

    const ai = getGeminiClient();
    const prompt = `
Você é o assistente de voz cirúrgico de uma agenda inteligente para dispositivos móveis (Android e iOS), focada em idosos e pessoas esquecidas.
O usuário disse o seguinte comando de voz (que pode ter palavras embaralhadas ou ordem confusa): "${transcript}"
Data e hora atuais de referência: "${currentDateTime || new Date().toISOString()}"

Sua tarefa é:
1. Interpretar com precisão cirúrgica a intenção, mesmo se o usuário se enrolou na ordem de falar o horário ou a frequência.
2. Identificar linhas de tempo complexas de recorrência (ex: "todos os dias", "a cada 3 dias", "a cada hora", "a cada 10 minutos", "toda segunda-feira", ou "único").
3. Corrigir eventuais confusões de horário absurdas (ex: se disser "3 da manhã" para tomar remédio ou consulta diurna, ajuste coerentemente para "15:00" ou equivalente lógico e explique na nota).
4. Retornar APENAS um JSON estrito (sem markdown extra) com este formato:
{
  "title": "Título curto e claro do compromisso ou tarefa",
  "date": "YYYY-MM-DD",
  "time": "HH:MM",
  "priority": "Alta" | "Média" | "Baixa",
  "category": "Saúde/Remédio" | "Família" | "Consulta" | "Casa" | "Outros",
  "recurrence": "Único" | "Todos os dias" | "A cada 3 dias" | "A cada hora" | "A cada minutos" | "Semanal",
  "correctionNote": "Explicação amigável caso tenha corrigido confusão de horário ou ordem de fala, ou string vazia.",
  "spokenConfirmation": "Uma frase curta, calorosa e muito clara em português para o aplicativo falar em voz alta confirmando o agendamento."
}
`;

    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: prompt,
    });

    const text = response.text || "";
    // Clean up markdown code blocks if present
    const cleanedJson = text.replace(/```json/g, "").replace(/```/g, "").trim();
    const parsedData = JSON.parse(cleanedJson);

    res.json(parsedData);
  } catch (error: any) {
    console.error("Error parsing voice command:", error);
    // Fallback response on error
    res.json({
      title: req.body.transcript || "Novo Compromisso",
      date: new Date().toISOString().split("T")[0],
      time: "10:00",
      priority: "Média",
      category: "Outros",
      correctionNote: "",
      spokenConfirmation: "Compromisso anotado com sucesso!"
    });
  }
});

// API endpoint for AI daily health/schedule briefing and tips for elderly care
app.post("/api/briefing", async (req, res) => {
  try {
    const { tasks } = req.body;
    const apiKey = process.env.GEMINI_API_KEY;
    
    if (!apiKey) {
      return res.json({
        greeting: "Bom dia! Você tem compromissos importantes hoje. Lembre-se de tomar seus remédios no horário certo.",
        tips: ["Beba bastante água", "Faça uma caminhada leve"]
      });
    }

    const ai = getGeminiClient();
    const prompt = `
Com base nestas tarefas do usuário idoso: ${JSON.stringify(tasks || [])},
Gere um resumo diário carinhoso, em português, com:
1. "greeting": Uma frase de bom dia acolhedora e motivadora.
2. "tips": Uma lista com 2 dicas curtas e práticas de saúde e bem-estar para o dia.
Responda em formato JSON estrito:
{
  "greeting": "...",
  "tips": ["...", "..."]
}
`;
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: prompt,
    });
    const cleaned = (response.text || "").replace(/```json/g, "").replace(/```/g, "").trim();
    res.json(JSON.parse(cleaned));
  } catch (err) {
    res.json({
      greeting: "Tenha um dia maravilhoso e cheio de energia!",
      tips: ["Mantenha-se hidratado", "Respire fundo e sorria"]
    });
  }
});

async function startServer() {
  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
