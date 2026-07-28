library;

import 'package:flutterflow_ai/flutterflow_ai.dart';

App buildPostgresCompileOnly(App app) {
  app.postgres(
    url: 'https://postgres.example.com',
    anonKey: 'postgres-anon-key',
  );

  final tickets = app.table(
    'tickets',
    fields: {
      'id': const PostgresTableField(
        string,
        postgresType: 'uuid',
        isPrimaryKey: true,
        hasDefault: true,
      ),
      'title': const PostgresTableField(
        string,
        postgresType: 'text',
        isRequired: true,
      ),
      'priority': const PostgresTableField(int_, postgresType: 'int4'),
      'resolved': const PostgresTableField(
        bool_,
        postgresType: 'bool',
        hasDefault: true,
      ),
    },
    description: 'Compile-only generic Postgres ticket rows.',
  );

  app.page(
    'PostgresTicketsPage',
    route: '/',
    isInitial: true,
    state: {
      'tickets': listOf(tickets),
      'title': string,
      'priority': int_.withDefault(1),
    },
    onLoad: [
      PostgresQuery(
        tickets,
        outputAs: 'tickets',
        query: PostgresQuerySpec(
          orderBys: const [PostgresOrderBy('priority', ascending: false)],
        ),
      ),
      SetState('tickets', ActionOutput('tickets')),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Tickets'),
      body: Column(
        spacing: 16,
        children: [
          TextField(
            name: 'TicketTitleField',
            label: 'Title',
            onChanged: SetState('title', const TextValue()),
          ),
          Button(
            'Create Ticket',
            name: 'CreateTicketButton',
            onTap: [
              PostgresCreate(
                tickets,
                fields: {
                  'title': State('title'),
                  'priority': State('priority'),
                  'resolved': false,
                },
              ),
            ],
          ),
          Button(
            'Resolve High Priority',
            name: 'ResolveButton',
            onTap: [
              PostgresUpdate(
                tickets,
                fields: {'resolved': true},
                query: PostgresQuerySpec(
                  filters: [
                    PostgresFilter(
                      'priority',
                      relation: PostgresFilterRelation.greaterThanOrEqualTo,
                      value: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
          ListView(
            source: State('tickets'),
            itemBuilder:
                (item) => Container(
                  name: 'TicketRow',
                  padding: 12,
                  child: Column(
                    crossAxis: CrossAxis.start,
                    spacing: 8,
                    children: [
                      Text(item['title'], name: 'TicketTitleText'),
                      Text(item['priority'], name: 'TicketPriorityText'),
                      Button(
                        'Delete',
                        name: 'DeleteTicketButton',
                        variant: ButtonVariant.text,
                        onTap: [
                          PostgresDelete(
                            tickets,
                            query: PostgresQuerySpec(
                              filters: [
                                PostgresFilter(
                                  'id',
                                  relation: PostgresFilterRelation.equalTo,
                                  value: item['id'],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    ),
  );

  return app;
}
