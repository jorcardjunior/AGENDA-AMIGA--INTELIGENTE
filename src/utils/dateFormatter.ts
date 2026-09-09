export const formatNaturalDate = (dateStr: string): string => {
  if (!dateStr) return 'data não informada';
  
  // Clean up format like YYYY-MM-DD
  const parts = dateStr.split('-');
  if (parts.length === 3) {
    const year = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10) - 1;
    const day = parseInt(parts[2], 10);

    const fullMonthNames = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];

    const fullDayNames = [
      'domingo', 'segunda-feira', 'terça-feira', 'quarta-feira',
      'quinta-feira', 'sexta-feira', 'sábado'
    ];

    try {
      const d = new Date(year, month, day);
      const dayOfWeek = fullDayNames[d.getDay()];
      const monthName = fullMonthNames[month] || 'mês';
      return `${dayOfWeek}, dia ${day} de ${monthName} de ${year}`;
    } catch (e) {
      // fallback
    }
  }
  return dateStr;
};

export const formatNaturalTime = (timeStr: string): string => {
  if (!timeStr) return '';
  const parts = timeStr.split(':');
  if (parts.length >= 2) {
    const hours = parseInt(parts[0], 10);
    const minutes = parseInt(parts[1], 10);
    if (minutes === 0) {
      return `${hours} horas`;
    }
    return `${hours} horas e ${minutes} minutos`;
  }
  return timeStr;
};
