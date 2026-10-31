/// OPR for one event: team number -> score-breakdown field -> contribution.
typedef OprData = Map<int, Map<String, double>>;

/// GetOPRData rows (one per team, `teamNumber` plus numeric fields) by team.
OprData oprFromJson(List rows) => {
      for (final r in rows.cast<Map>())
        if (r['teamNumber'] is num)
          (r['teamNumber'] as num).toInt(): {
            for (final e in r.entries)
              if (e.key != 'teamNumber' && e.value is num)
                e.key as String: (e.value as num).toDouble(),
          },
    };
