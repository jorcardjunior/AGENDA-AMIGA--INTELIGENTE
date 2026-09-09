/// Classifies a commitment into a speech intent, based on keywords related to
/// what the user is being reminded of. Works 100% offline (rule-based NLP) and
/// is deterministic — the device never leaves the device.
library;

/// The likeliest intent of a commitment, used to pick the tone + closings.
enum CommitmentIntent {
  wakeUp, // acordar / levantar / despertar
  medication, // remédio / medicamento / dose / insulina (maior gravidade)
  healthAppointment, // consulta / exame / médico / dentista
  call, // ligar / telefonar / chamar alguém
  family, // aniversário / visitar parente / família
  payment, // pagar conta / boleto / fatura
  work, // reunião / entrevista / prazo / cliente / médico (profissional)
  home, // casa / limpeza / objetos / contas domésticas
  errand, // mercado / farmácia / correio / banco (sair para resolver)
  meal, // café da manhã / almoço / jantar / remédio junto à refeição
  spiritual, // igreja / oração / missa / devocional
  study, // estudar / lição / prova / revisão
  exercise, // caminhada / academia / fisioterapia
  rest, // descansar / dormir / pausa / relaxar
  generic, // fallback — nunca retorna erro
}

/// How urgent/caring the alarm tone should be.
enum SpeechGravity { high, medium, low }

class IntentResult {
  final CommitmentIntent intent;
  final SpeechGravity gravity;

  const IntentResult(this.intent, this.gravity);

  static const high = SpeechGravity.high;
  static const medium = SpeechGravity.medium;
  static const low = SpeechGravity.low;
}

class IntentClassifier {
  // NOTE: keys are stored WITHOUT accents because _normalize() lowercases the
  // input and strips all accents before matching.
  static const Map<CommitmentIntent, Map<String, int>> _keywords = {
    CommitmentIntent.wakeUp: {
      'acordar': 3, 'acorda': 3, 'acorde': 3, 'levantar': 3, 'levanto': 2,
      'despertar': 3, 'desperta': 2, 'desperte': 2, 'cafe da manha': 1,
      'comecar o dia': 1, 'iniciar o dia': 1, 'encarar o dia': 1,
      'cafe': 1, 'despertador': 2,
    },
    CommitmentIntent.medication: {
      'remedio': 4, 'medicamento': 4, 'comprimido': 4,
      'dose': 3, 'insulina': 4, 'aplicar': 2, 'tomar': 2, 'pilula': 4,
      'gotas': 3, 'vitamina': 3, 'xarope': 3, 'colirio': 3,
      'soro': 3, 'injecao': 4, 'capsula': 3, 'suplemento': 3,
      'antibiotico': 4, 'analgesico': 4, 'antitermico': 4,
      'tireoide': 3, 'pressao': 2, 'pomada': 3, 'inalador': 3,
      'bomba de': 2, 'reposicao': 2, 'hormonio': 3,
    },
    CommitmentIntent.healthAppointment: {
      'consulta': 4, 'medico': 4, 'medica': 4, 'dentista': 4, 'exame': 4,
      'exames': 4, 'hospital': 3, 'clinica': 3, 'check-up': 4, 'checkup': 4,
      'radiografia': 3, 'ultrassom': 3, 'cardiologista': 4,
      'dermatologista': 4, 'ginecologista': 4, 'ortopedista': 4,
      'fisioterapeuta': 4, 'oftalmologista': 4, 'psicologo': 3,
      'psiquiatra': 3, 'vacina': 4, 'vacinacao': 4,
      'colesterol': 3, 'glicemia': 3, 'hemograma': 3, 'ecocardiograma': 3,
      'ressonancia': 3, 'tomografia': 3, 'banco de sangue': 3,
      'cirurgia': 4, 'pos-operatorio': 4,
    },
    CommitmentIntent.call: {
      'ligar': 4, 'ligue': 4, 'telefonar': 4, 'telefone': 3, 'chamar': 3,
      'chame': 3, 'videochamada': 3, 'videocall': 3, 'ligacao': 4,
      'discar': 3, 'retornar a ligacao': 4, 'retornar o contato': 4,
      'falar com': 3, 'entrar em contato': 3, 'contatar': 3,
      'enviar mensagem': 2, 'mandar mensagem': 2, 'enviar whatsapp': 2,
      'mandar zap': 2, 'whatsapp': 2, 'sms': 2, 'email': 2, 'e-mail': 2,
    },
    CommitmentIntent.family: {
      'aniversario': 4, 'aniversariante': 4, 'visitar': 3, 'familia': 3,
      'mae': 3, 'mamae': 3, 'pai': 3, 'namorada': 3, 'namorado': 3,
      'esposa': 3, 'marido': 3, 'filho': 3, 'filha': 3, 'neta': 3, 'neto': 3,
      'avo': 3, 'av,' : 3, 'primo': 3, 'prima': 3, 'tio': 3, 'tia': 3,
      'sobrinho': 3, 'sobrinha': 3, 'genro': 3, 'nora': 3, 'cunhado': 3,
      'cunhada': 3, 'casamento': 3, 'batizado': 3, 'cha de bebe': 3,
      'comemorar': 3, 'confraternizacao': 3, 'almoco de domingo': 3,
      'reuniao familiar': 3, 'conversar com': 2,
    },
    CommitmentIntent.payment: {
      'pagar': 4, 'boleto': 4, 'conta': 3, 'fatura': 4, 'imposto': 4,
      'parcela': 4, 'pix': 3, 'carne': 4, 'mensalidade': 4,
      'prestacao': 4, 'debito': 4, 'banco': 3, 'cartao': 3,
      'cobranca': 4, 'luz': 3, 'internet': 3, 'telefone': 2, 'agua': 3,
      'condominio': 3, 'seguro': 3, 'taxa': 3, 'tarifa': 3,
      'transferencia': 3, 'aplicativo de banco': 3,
    },
    CommitmentIntent.work: {
      'reuniao': 4, 'entrevista': 4, 'prazo': 4, 'cliente': 4,
      'apresentacao': 4, 'relatorio': 3, 'palestra': 4, 'workshop': 4,
      'plantao': 4, 'jornada': 3, 'expediente': 3, 'trabalho': 3,
      'trabalhar': 3, 'delivery': 3, 'entrega': 3, 'pedido': 3, 'projeto': 3,
      'chamada de trabalho': 4, 'briefing': 4, 'congresso': 4,
      'seminario': 4, 'aula magistral': 3,
    },
    CommitmentIntent.home: {
      'casa': 3, 'limpeza': 3, 'lavar': 3, 'passar': 2, 'cozinhar': 2,
      'almoco em casa': 2, 'jantar em casa': 2, 'arrumar': 3, 'organizar': 3,
      'conserto': 3, 'manutencao': 3, 'jardinagem': 3, 'regar': 3, 'rega': 2,
      'plantas': 3, 'encomenda': 3, 'mudanca': 3, 'feira': 2,
      'receber visita': 3, 'receber alguem': 3, 'preparar': 2, 'cozinha': 2,
      'eletrodomestico': 3,
    },
    CommitmentIntent.errand: {
      'mercado': 4, 'supermercado': 4, 'farmacia': 4, 'correio': 4,
      'padaria': 3, 'banco': 2, 'loja': 3, 'shopping': 3, 'comprar': 3,
      'compras': 3, 'doceria': 3, 'acougue': 3, 'quitanda': 3,
      'hospital': 1, 'papelaria': 3, 'cartorio': 3, 'consulado': 3,
      'agencia': 3, 'posto': 3, 'usar maquina': 2,
    },
    CommitmentIntent.meal: {
      'cafe da manha': 4, 'almoco': 4, 'jantar': 4, 'lanche': 3,
      'lanchinho': 3, 'ceia': 4, 'merenda': 3, 'cafe': 2, 'cha': 2,
      'refeicao': 4, 'comer': 3, 'tomar cafe': 3, 'tomar leite': 3,
      'preparar o cafe': 3, 'armazenar alimentos': 2, 'hidratar': 2,
      'beber agua': 3, 'agua': 2, 'suco': 2, 'vitamina': 2, 'fruta': 2,
    },
    CommitmentIntent.spiritual: {
      'igreja': 4, 'missa': 4, 'oracao': 4, 'rezar': 4, 'devocional': 4,
      'biblia': 4, 'culto': 4, 'estudo biblico': 4, 'grupo de oracao': 4,
      'celula': 4, 'reuniao da igreja': 4, 'templo': 3, 'peregrinacao': 4,
      'jejum': 4, 'louvor': 4, 'adoracao': 4, 'batismo': 4, 'eucaristia': 4,
      'terco': 4, 'novena': 4, 'retiro': 4, 'palavra de deus': 4,
    },
    CommitmentIntent.study: {
      'estudar': 4, 'prova': 4, 'licao': 4, 'revisao': 4, 'ler': 3,
      'leitura': 3, 'curso': 3, 'aula': 3, 'vestibular': 4, 'concurso': 4,
      'redacao': 3, 'tarefa de casa': 4, 'dever de casa': 4, 'tcc': 3,
      'monografia': 3, 'dissertacao': 3, 'tese': 3, 'resumo': 3,
      'fichamento': 3, 'trabalho academico': 3, 'projeto de pesquisa': 3,
    },
    CommitmentIntent.exercise: {
      'caminhada': 4, 'academia': 4, 'exercicio': 4, 'alongamento': 4,
      'ioga': 4, 'yoga': 4, 'pilates': 4, 'natacao': 4, 'bicicleta': 3,
      'pedalar': 3, 'correr': 3, 'caminhar': 3, 'musculacao': 4,
      'danca': 3, 'treino': 4, 'fisioterapia': 4, 'funcional': 4,
      'zumba': 4, 'hidroginastica': 4, 'bolar': 1, 'jogar bola': 3,
      'atividade fisica': 4, 'se mexer': 3,
    },
    CommitmentIntent.rest: {
      'descansar': 4, 'dormir': 4, 'cochilo': 4, 'soneca': 4, 'pausa': 3,
      'relaxar': 4, 'relaxamento': 4, 'meditar': 4, 'meditacao': 4,
      'pressao de sono': 3, 'descanso': 4, 'tirar uma soneca': 4,
      'respirar fundo': 3, 'banho': 2, 'silencio': 3, 'desacelerar': 4,
      'mastigar devagar': 2, 'paciencia': 2,
    },
  };

  /// Scores each intent and returns the strongest match. Ties resolved by a
  /// priority order (medication/appointment win over generic).
  static IntentResult classify(String rawText) {
    final lower = _normalize(rawText);
    CommitmentIntent best = CommitmentIntent.generic;
    var bestScore = 0;

    _keywords.forEach((intent, scores) {
      var score = 0;
      scores.forEach((keyword, weight) {
        if (lower.contains(keyword)) {
          score += weight;
        }
      });
      if (score > bestScore) {
        best = intent;
        bestScore = score;
      }
    });

    // If nothing matched, check generic verbs that still deserve a caring tone.
    if (bestScore == 0) {
      if (lower.contains('lembrar') ||
          lower.contains('nao esquecer') ||
          lower.contains('anotar')) {
        best = CommitmentIntent.generic;
        bestScore = 1;
      }
    }

    // Health-related commitments are always high gravity.
    if (best == CommitmentIntent.medication ||
        best == CommitmentIntent.healthAppointment) {
      return IntentResult(best, SpeechGravity.high);
    }
    if (best == CommitmentIntent.payment ||
        best == CommitmentIntent.work) {
      return IntentResult(best, SpeechGravity.medium);
    }
    return IntentResult(best, SpeechGravity.low);
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[íí]'), 'i')
        .replaceAll(RegExp(r'[éè]'), 'e')
        .replaceAll(RegExp(r'[àáâã]'), 'a')
        .replaceAll(RegExp(r'[õô]'), 'o')
        .replaceAll(RegExp(r'ç'), 'c')
        .replaceAll(RegExp(r'[úù]'), 'u')
        .trim();
  }
}