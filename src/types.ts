export interface Commitment {
  id: string;
  title: string;
  date: string; // YYYY-MM-DD
  time: string; // HH:MM
  priority: 'Alta' | 'Média' | 'Baixa';
  category: 'Saúde/Remédio' | 'Família' | 'Consulta' | 'Casa' | 'Outros';
  completed: boolean;
  correctionNote?: string;
  reminderMinutesBefore?: number;
  recurrence?: string; // e.g. "Todos os dias", "A cada 3 dias", "A cada hora", "Único"
}

