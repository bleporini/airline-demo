variable "ddls1st" {
  type    = map(any)
  default = {

    request-topic=<<-EOT
create table requestTopic(
                             key row<`flight_id` string, `reference` string>  primary key not enforced,
                             val bytes,
                             `headers` map<string,string> metadata,
                              ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' virtual

)distributed by (key) into 1 buckets with(
   'key.format'='json-registry',
   'kafka.consumer.isolation-level' = 'read-uncommitted',
   'value.format'='raw'
       );
EOT
    passport-request-topic=<<-EOT
create table passport_requests(
    key string primary key not enforced,
    flight_id string,
    name string,
    date_of_birth string,
    passport_number string,
    seat_number string,
    class string,
    deleted boolean,
    details_completed boolean,
    `headers` map<string,string> metadata,
    ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' virtual
)distributed by(key) into 1 buckets with(
    'key.format'='raw',
    'kafka.consumer.isolation-level' = 'read-uncommitted',
    'value.format'='json-registry'
);
EOT

    subs-requests = <<-EOT
create table subscriptionsRequests(
                             key string primary key not enforced,
                             val bytes,
                             `headers` map<string,string> metadata,
                              ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' virtual
)distributed by (key) into 1 buckets with(
   'key.format'='json-registry',
   'kafka.consumer.isolation-level' = 'read-uncommitted',
   'value.format'='raw'
);
EOT
   notif-req  = <<-EOT
create table notificationsRequests(
                              key string primary key not enforced ,
                              val bytes,
                             `headers` map<string,string> metadata,
                              ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' virtual
) distributed by (key) into 1 buckets with(
   'key.format'='json-registry',
   'kafka.consumer.isolation-level' = 'read-uncommitted',
   'value.format'='raw'
     );
EOT
  flight-information-xml = <<-EOT
create table flight_information_xml (
  val bytes,
 `headers` map<string,string> metadata,
  ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' virtual
) distributed into 1 buckets with(
   'kafka.consumer.isolation-level' = 'read-uncommitted',
    'value.format'='raw'
)
;

EOT
  }

}

variable "ddls" {
  type    = map(any)
  default = {
/*
    intermediate-flight-information = <<-EOT
create table intermediate_flight_information as
select xml_to_key(val) as key, xml_to_info(val) as v, ts  from `flight_information_xml`;
EOT
*/
    intermediate-flight-information = <<-EOT
CREATE TABLE `flights`.`intermediate_flight_information` (
  `key` string,
  `v` ROW<
          `error` string,
          `orResult` ROW<
            `flight_number` string,
            `carrier` string, 
            `departure_timestamp` BIGINT,
            `origin` string, 
            `destination` string, 
            `passengers` ARRAY<ROW<`reference` string, 
            `name` string, 
            `date_of_birth` string, 
            `passport_number` string, 
            `seat_number` string, 
            `class` string, 
            `deleted` BOOLEAN
          >
        >
      >
    >,
  `ts` TIMESTAMP(3) WITH LOCAL TIME ZONE
)with(
   'kafka.consumer.isolation-level' = 'read-uncommitted'
);
EOT
    flight-information = <<-EOT
create table flight_information(
                                    key string,
                                    flight_number string not null,
                                    carrier string not null,
                                    departure_timestamp bigint not null ,
                                    origin string not null,
                                    destination string not null,
                                    passengers array<
                                        row<
                                            reference string not null,
                                            name string not null ,
                                            date_of_birth string,
                                            passport_number string,
                                            seat_number string,
                                            class string,
                                            deleted boolean
                                        >
                                    >,
                             `headers` map<string,string> metadata,
                              ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' virtual
) distributed by (key) into 1 buckets with(
       'key.format'='raw',
      'value.format'='json-registry',
      'kafka.consumer.isolation-level' = 'read-uncommitted',
      'changelog.mode'='append'
      );
EOT
    passengers          = <<-EOT
create table passengers(
    key string primary key not enforced,
    flight_id string,
    name string,
    date_of_birth string,
    passport_number string,
    seat_number string,
    class string,
    deleted boolean,
    details_completed boolean,
    `headers` map<string,string> metadata,
    ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' virtual
)distributed by(key) into 1 buckets with(
    'key.format'='json-registry',
    'kafka.consumer.isolation-level' = 'read-uncommitted',
    'value.format'='json-registry'
);
EOT
    cms-event           = <<-EOT
create table cms_event(
    key string,
    economy_meals int,
    premium_meals int,
    business_meals int,
    first_meals int,
    event_time TIMESTAMP(3) METADATA FROM 'timestamp' virtual,
    `headers` map<string,string> metadata,
    WATERMARK FOR event_time AS event_time
) distributed by (key) into 1 buckets with(
   'key.format'='raw',
   'value.format'='json-registry',
   'kafka.consumer.isolation-level' = 'read-uncommitted',
   'changelog.mode'='append'
);
EOT
    alert-attempts      = <<-EOT
create table alert_attempts(
      key string,
      economy_meals int,
      economy_passengers int,
      premium_meals int,
      premium_passengers int,
      business_meals int,
      business_passengers int,
      first_meals int,
      first_passengers int,
     `headers` map<string,string> metadata,
      event_time TIMESTAMP(3) METADATA FROM 'timestamp' virtual,
      WATERMARK FOR event_time AS event_time
) distributed by (key) into 1 buckets with(
   'kafka.consumer.isolation-level' = 'read-uncommitted',
   'key.format'='json-registry',
   'value.format'='json-registry'
)
EOT
    meals-per-flights   = <<-EOT
create table meals_per_flights(
    key string primary key not enforced,
    eco int,
    prem int,
    biz int,
    first int,
    `headers` map<string,string> metadata,
    event_time TIMESTAMP(3) METADATA FROM 'timestamp' virtual,
    WATERMARK FOR event_time AS event_time
)distributed by (key) into 1 buckets with(
    'kafka.consumer.isolation-level' = 'read-uncommitted',
    'key.format'='json-registry',
    'value.format'='json-registry'
);
EOT
    alerts              = <<-EOT
create table alerts(
    key string,
    type string,
    cms row<
        economy_meals int,
        premium_meals int,
        business_meals int,
        first_meals int
    >,
    flight row<
        economy int,
        premium int,
        business int,
        first int
    >,
    ts TIMESTAMP(3) METADATA FROM 'timestamp' virtual,
    `headers` map<string,string> metadata
    ) distributed by (key) into 1 buckets with(
   'kafka.consumer.isolation-level' = 'read-uncommitted',
   'key.format'='json-registry',
   'value.format'='json-registry'

);
EOT
    last-alerts         = <<-EOT
create table last_alerts(
    key string primary key not enforced ,
    type string,
    `headers` map<string,string> metadata,
    event_time TIMESTAMP(3) METADATA FROM 'timestamp' virtual,
    WATERMARK FOR event_time AS event_time
) distributed by (key) into 1 buckets with(
   'kafka.consumer.isolation-level' = 'read-uncommitted',
   'key.format'='json-registry',
   'value.format'='json-registry'
);
EOT
    flights = <<-EOT
create table flights(
                                    key string primary key not enforced ,
                                    flight_number string not null,
                                    carrier string not null,
                                    departure_timestamp bigint not null ,
                                    origin string not null,
                                    destination string not null,
                                    passengers multiset<
                                        row<
                                            reference string,
                                            name string,
                                            date_of_birth string,
                                            passport_number string,
                                            seat_number string,
                                            class string
                                        >
                                    >,
                                    ts TIMESTAMP(3) METADATA FROM 'timestamp' virtual,
                                    `headers` map<string,string> metadata
) with(
   'kafka.consumer.isolation-level' = 'read-uncommitted',
   'key.format'='json-registry',
  'value.format'='json-registry'
      );
EOT
chekin = <<-EOT
create table checkin_open_events(
                                    key string,
                                    event_name string,
                                    ts TIMESTAMP(3) METADATA FROM 'timestamp' virtual
) distributed by (key) with(
   'kafka.consumer.isolation-level' = 'read-uncommitted',
   'key.format'='raw',
   'value.format'='json-registry'
);
EOT


response-topic = "create table responseTopic like requestTopic;"
    subs-resp = "create table subscriptionsResponses like subscriptionsRequests;"
    notif-resp = "create table notificationsResponses like notificationsRequests;"
  }
}

/*
<<-EOT
EOT
*/

variable "dmls" {
  type = map(any)
  default = {
    xml-to-json=<<-EOT
insert into `intermediate_flight_information`
select xml_to_key(val) as key, xml_to_info(val) as v, ts  from `flight_information_xml`
;
EOT
    intermediate-to-flight-information= <<-EOT
insert into `flight_information`
select
    key,
    v.orResult.flight_number,
    v.orResult.carrier,
    v.orResult.departure_timestamp,
    v.orResult.origin,
    v.orResult.destination,
    v.orResult.passengers,
    map[
      'ts_from_flight_information_xml', cast (ts as string)
    ] as `headers`
from `intermediate_flight_information`
where v.error is null;
EOT
    unnest-passenders         = <<-EOT
insert into passengers select
    p.reference as key,
    key as flight_id,
    p.name,
    p.date_of_birth  as date_of_birth,
    p.passport_number as passport_number,
    p.seat_number as seat_number,
    p.class as class,
    p.deleted as deleted,
    false as details_completed,
    map_union(
      headers,
      map[
          'origin', 'unnest query',
          'ts_from_flight_information', cast(ts as string)
      ]
    ) as `headers`
from flight_information fi cross join unnest(fi.passengers) as p
;
EOT
    sum-meals                 = <<-EOT
insert into meals_per_flights
select
    flight_id as key,
    sum(if(class='economy', 1, 0))  as eco,
    sum(if(class='premium', 1, 0))  as prem,
    sum(if(class='business', 1, 0)) as biz,
    sum(if(class='first', 1, 0))    as first,
    map['dummy', 'dummy']
from passengers where deleted <> true
group by flight_id
;
EOT
    genreate-alerts           = <<-EOT
insert into alerts
with a as (
    select
    key,
    row(
        economy_meals,
        premium_meals,
        business_meals,
        first_meals
    ) as cms,
    row(
        economy_passengers,
        premium_passengers,
        business_passengers,
        first_passengers
    ) as flight,
    event_time as curr,
    lag(event_time, 1, timestampadd(hour,-1, event_time)) over (partition by key order by event_time) as `prev`
from alert_attempts
    )
select
    key,
    'meal_shortage',
    cms,
    flight,
    map[
        'current', date_format(curr, 'yyyy-MM-dd HH:mm:ss'),
        'previous', date_format(`prev`, 'yyyy-MM-dd HH:mm:ss')
    ] as `headers`
from a
where timestampdiff(second, `prev`, curr) > 120
;
EOT
    store-last-alert          = <<-EOT
insert into last_alerts
select
    key,
    last_value(type) as type,
    headers
from alerts
group by key, headers
;
EOT
/*
    update-passenger= <<-EOT
insert into passengers
with r as (
    select
        key,
        cast (val as string) as json,
        ts
    from responseTopic
)
select
    key.reference as key,
    key.flight_id as flight_id,
    json_value(json, '$.value.name') as name,
    json_value(json, '$.value.date_of_birth') as date_of_birth ,
    json_value(json_value(json, '$.response'),'$.passport_number') as passport_number ,
    json_value(json, '$.value.seat_number') as seat_number ,
    json_value(json, '$.value.class') as class ,
    lower(json_value(json, '$.value.deleted')) = 'true' as deleted,
    true as details_completed,
    map[
      'origin', 'passport query2',
      'ts_from_response_topic', cast(ts as string)
    ] as `headers`
from r;
EOT
*/

    gen-subs-req= <<-EOT
insert into subscriptionsRequests
select
    p1.flight_id,
    cast (
            json_object(
                'url' value 'https://qylcpzjqayixabnqcc6edkwepm0whtkn.lambda-url.eu-west-1.on.aws?subscribers=all'
            )as bytes),
    headers
from
(select key, flight_id, headers, count(*) as total from passengers group by key, flight_id, headers) p1 join
(select key, count(*) as completed from passengers where details_completed=true group by key) p2 on p1.key = p2.key
where p1.total = p2.completed;
    EOT

    gen-notif-req = <<-EOT
insert into notificationsRequests
with r as (
    select
      key,
      json_query(
        json_value(cast(val as string), '$.response'),
        '$' returning array<string>
      ) as urls,
      headers
    from subscriptionsResponses
)select
         r.key,
         cast (
                 json_object(
                         'url' value u.url
                     )as bytes
             ),
        headers
     from r cross join unnest(r.urls) as u(url);
EOT
    populate-flights= <<-EOT
insert into flights
select
    f.key,
    f.flight_number,
    f.carrier,
    f.departure_timestamp,
    f.origin,
    f.destination,
    collect(
        (p.key, p.name, p.date_of_birth, p.passport_number, p.seat_number, p.class)
    ) as passengers,
    map['origin', 'from passengers query'] as `headers`
from passengers p join flight_information f on p.flight_id = f.key
where p.deleted is null or p.deleted<>true
group by f.key,    f.flight_number,
    f.carrier,
    f.departure_timestamp,
    f.origin,
    f.destination
;
EOT

  }
}


/*
<<-EOT
EOT
*/
