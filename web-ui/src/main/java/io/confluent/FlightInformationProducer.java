package io.confluent;

import io.confluent.ek.CheckinOpenEventsValueSchema;
import io.confluent.ek.CmsEventValueSchema;
import io.confluent.ek.FlightInformationValueSchema;
import io.confluent.kafka.serializers.json.KafkaJsonSchemaSerializer;
import io.confluent.kafka.serializers.json.KafkaJsonSchemaSerializerConfig;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.ByteArraySerializer;
import org.apache.kafka.common.serialization.StringSerializer;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

public class FlightInformationProducer {

    private KafkaProducer<String, Object> producer;
    private KafkaProducer<String, byte[]> xmlProducer;



    public FlightInformationProducer(Properties properties) {
        Properties props = (Properties) properties.clone();
        props.put(ProducerConfig.CLIENT_ID_CONFIG, "web-ui-producer");
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaJsonSchemaSerializer.class);
        props.put(KafkaJsonSchemaSerializerConfig.AUTO_REGISTER_SCHEMAS, "false");
        props.put(KafkaJsonSchemaSerializerConfig.USE_LATEST_VERSION, "true");
        props.put(KafkaJsonSchemaSerializerConfig.LATEST_COMPATIBILITY_STRICT, "false");

        Properties props4xml = (Properties) properties.clone();
        props4xml.put(ProducerConfig.CLIENT_ID_CONFIG, "web-ui-producer");
        props4xml.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props4xml.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, ByteArraySerializer.class);

        producer = new KafkaProducer<>(props);
        xmlProducer = new KafkaProducer<>(props4xml);
    }

    public void send(String key, byte[] payload) {
        xmlProducer.send(
                new ProducerRecord<>(
                        "flight_information_xml",
                        key,
                        payload
                ),
                (metadata, exception) -> {
                    if (exception != null) {
                        exception.printStackTrace();
                    }else{
                        System.out.println("metadata = " + metadata);
                    }
                }
        );

    }

    private <V> void send(String topic, String key, V payload) {
        producer.send(
                new ProducerRecord<>(
                        topic,
                        key,
                        payload
                ),
                (metadata, exception) -> {
                    if (exception != null) {
                        exception.printStackTrace();
                    }else{
                        System.out.println("metadata = " + metadata);
                    }
                }
        );

    }

    public void send(String key, FlightInformationValueSchema fi) {
        send(
                "flight_information",
                key,
                fi
        );
    }

    public void send(String key, CheckinOpenEventsValueSchema checkinOpenEventsValueV1) {
        send(
                "checkin_open_events",
                key,
                checkinOpenEventsValueV1

        );
    }

    public void send(String key, CmsEventValueSchema cmsEvent) {
        send(
                "cms_event",
                key,
                cmsEvent
        );
    }
}
