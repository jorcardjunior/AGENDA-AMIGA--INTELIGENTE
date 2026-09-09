export interface ParsedCommand {
  title: string;
  date: string;
  time: string;
  recurrence: string;
  category: string;
  priority: 'Alta' | 'Média' | 'Baixa';
  rawText: string;
}

export function parseNaturalCommand(text: string): ParsedCommand {
  const lower = text.toLowerCase();
  
  // 1. Category and Priority detection
  let category = 'Outros';
  let priority: 'Alta' | 'Média' | 'Baixa' = 'Média';

  if (lower.includes('remedio') || lower.includes('remédio') || lower.includes('medicamento') || lower.includes('comprimido') || lower.includes('gota') || lower.includes('vitamina') || lower.includes('pressão') || lower.includes('dor')) {
    category = 'Saúde/Remédio';
    priority = 'Alta';
  } else if (lower.includes('consulta') || lower.includes('medico') || lower.includes('médico') || lower.includes('doutor') || lower.includes('exame') || lower.includes('hospital')) {
    category = 'Consulta';
    priority = 'Alta';
  } else if (lower.includes('filho') || lower.includes('filha') || lower.includes('neto') || lower.includes('familia') || lower.includes('família') || lower.includes('esposa') || lower.includes('marido')) {
    category = 'Família';
    priority = 'Média';
  } else if (lower.includes('casa') || lower.includes('agua') || lower.includes('luz') || lower.includes('comida') || lower.includes('mercado')) {
    category = 'Casa';
    priority = 'Média';
  }

  // 2. Recurrence detection
  let recurrence = 'Único';
  if (lower.includes('de hora em hora') || lower.includes('a cada hora')) {
    recurrence = 'De hora em hora';
  } else if (lower.includes('a cada 2 horas') || lower.includes('a cada duas horas')) {
    recurrence = 'A cada 2 horas';
  } else if (lower.includes('a cada 3 horas') || lower.includes('a cada três horas')) {
    recurrence = 'A cada 3 horas';
  } else if (lower.includes('todos os dias') || lower.includes('diariamente') || lower.includes('todo dia')) {
    recurrence = 'Todos os dias';
  } else if (lower.includes('a cada 3 dias') || lower.includes('a cada três dias')) {
    recurrence = 'A cada 3 dias';
  } else if (lower.includes('semanal') || lower.includes('toda semana')) {
    recurrence = 'Semanal';
  }

  // 3. Time calculation
  const now = new Date();
  let targetTime = new Date(now);

  // Check for "daqui a X minutos"
  const minMatch = lower.match(/daqui a (\d+) min/);
  if (minMatch) {
    const mins = parseInt(minMatch[1], 10);
    targetTime.setMinutes(now.getMinutes() + mins);
  } else {
    // Check for specific time like "ás 8:30", "as 14h", "9 horas"
    const timeMatch = lower.match(/(?:às|as|à|a)?\s*(\d{1,2})(?::(\d{2}))?\s*(h|horas|da manhã|da tarde|da noite)?/);
    if (timeMatch) {
      let h = parseInt(timeMatch[1], 10);
      let m = timeMatch[2] ? parseInt(timeMatch[2], 10) : 0;
      if (lower.includes('noite') && h < 12) h += 12;
      if (lower.includes('tarde') && h < 12) h += 12;
      targetTime.setHours(h, m, 0, 0);
      if (targetTime < now && !lower.includes('amanhã')) {
        // If time already passed today, set for tomorrow or keep
      }
    } else {
      // Default +1 hour if no time specified
      targetTime.setHours(now.getHours() + 1, 0, 0, 0);
    }
  }

  // Check for "amanhã"
  if (lower.includes('amanhã') || lower.includes('amanha')) {
    targetTime.setDate(targetTime.getDate() + 1);
  }

  const timeStr = `${targetTime.getHours().toString().padStart(2, '0')}:${targetTime.getMinutes().toString().padStart(2, '0')}`;
  const dateStr = targetTime.toISOString().split('T')[0];

  return {
    title: text.charAt(0).toUpperCase() + text.slice(1),
    date: dateStr,
    time: timeStr,
    recurrence,
    category,
    priority,
    rawText: text,
  };
}
