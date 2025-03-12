package io.confluent;

import io.confluent.ek.*;
import io.confluent.kafka.serializers.json.KafkaJsonSchemaDeserializer;
import io.confluent.kafka.serializers.json.KafkaJsonSchemaDeserializerConfig;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.ByteArrayDeserializer;
import org.apache.kafka.common.serialization.Deserializer;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.io.IOException;
import java.io.InputStream;
import java.time.Duration;
import java.util.Collections;
import java.util.List;
import java.util.Properties;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.BiConsumer;

public class AbstractTypedConsumerFactory<K,V, KD extends Deserializer<K>, VD extends Deserializer<V>> {

    public static class TypedConsumerFactory{
        private final String propertiesPath;

        private TypedConsumerFactory(String propertiesPath) {
            this.propertiesPath = propertiesPath;
        }
        private Properties loadConfig(InputStream propsIS) throws IOException {
            Properties props = new Properties();
            props.load(propsIS);
            return props;
        }
        private Properties loadProperties() {
            try (InputStream propsIS = AbstractTypedConsumerFactory.class.getResourceAsStream(propertiesPath)) {
                return loadConfig(propsIS);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }

        }

        private <K,V, KD extends Deserializer<?>, VD extends Deserializer<?>> void setupConsumer(
                ConsumerRegistrator<K,V> registrator,
                String topic,
                Class<K> keyClass,
                Class<V> valueClass,
                Class<KD> keyDeserializer,
                Class<VD> valueDeserializer) {
            final Properties props = loadProperties();
            props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, keyDeserializer);
            props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, valueDeserializer);
            props.put(ConsumerConfig.ISOLATION_LEVEL_CONFIG, "read_uncommitted");
            props.put(KafkaJsonSchemaDeserializerConfig.JSON_KEY_TYPE, keyClass);
            props.put(KafkaJsonSchemaDeserializerConfig.JSON_VALUE_TYPE, valueClass);
            String groupId = props.getProperty("group.id");
            props.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
            props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "latest");
            try (KafkaConsumer<K, V> consumer = new KafkaConsumer<>(props)) {
                consumer.subscribe(Collections.singletonList(topic));
                while (true) {
                    ConsumerRecords<K, V> records = consumer.poll(Duration.ofMillis(1000));
                    for (ConsumerRecord<K, V> record : records) {
                        System.out.println("record = " + record);
                        if (record.value() == null) continue;
                        registrator.consumers.forEach(c -> c.accept(record.key(), record.value()));
                    }
                }
            }

        }

        public <K,V, KD extends Deserializer<?>, VD extends Deserializer<?>> ConsumerRegistrator<K, V> build(
                String topic,
                Class<K> keyClass,
                Class<V> valueClass,
                Class<KD> keyDeserializer,
                Class<VD> valueDeserializer
        ) {
            ConsumerRegistrator<K, V> registrator = new ConsumerRegistrator<>();
            new Thread(() -> setupConsumer(registrator,topic,keyClass, valueClass, keyDeserializer, valueDeserializer)).start();
            return registrator;
        }

        public ConsumerRegistrator<PassengersKeySchema, PassengersValueSchema> buildPassengerConsumer() {
            return build(
                    "passengers",
                    PassengersKeySchema.class,
                    PassengersValueSchema.class,
                    KafkaJsonSchemaDeserializer.class,
                    KafkaJsonSchemaDeserializer.class
            );
        }

        public ConsumerRegistrator<String, FlightInformationValueSchema> buildFlightInfoConsumer() {
            return build(
                    "flight_information",
                    String.class,
                    FlightInformationValueSchema.class,
                    StringDeserializer.class,
                    KafkaJsonSchemaDeserializer.class
            );
        }

        public ConsumerRegistrator<byte[], byte[]> buildRequestTopicConsumer() {
            return build(
                    "passport_requests",
                    byte[].class,
                    byte[].class,
                    ByteArrayDeserializer.class,
                    ByteArrayDeserializer.class
            );
        }
        public ConsumerRegistrator<byte[], byte[]> buildResponseTopicConsumer(String topicName) {
            return build(
                    topicName,
                    byte[].class,
                    byte[].class,
                    ByteArrayDeserializer.class,
                    ByteArrayDeserializer.class
            );
        }

        public  ConsumerRegistrator<MealsPerFlightsKeySchema, MealsPerFlightsValueSchema> buildRequiredMealsTopicConsumer() {
            return build(
                    "meals_per_flights",
                    MealsPerFlightsKeySchema.class,
                    MealsPerFlightsValueSchema.class,
                    KafkaJsonSchemaDeserializer.class,
                    KafkaJsonSchemaDeserializer.class
            );
        }
        public  ConsumerRegistrator<AlertsKeySchema, AlertsValueSchema> buildAlertTopicConsumer() {
            return build(
                    "alerts",
                    AlertsKeySchema.class,
                    AlertsValueSchema.class,
                    KafkaJsonSchemaDeserializer.class,
                    KafkaJsonSchemaDeserializer.class
            );
        }

    }

    public static TypedConsumerFactory configureFactory(String propertyPath) {
        return new TypedConsumerFactory(propertyPath);
    }

    public static class ConsumerRegistrator<K,V>{
        private final  List<BiConsumer<K, V>> consumers = new CopyOnWriteArrayList<>();

        public void register(BiConsumer<K, V> c) {
            consumers.add(c);
        }

    }


}
