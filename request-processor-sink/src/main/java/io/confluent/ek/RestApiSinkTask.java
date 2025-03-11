package io.confluent.ek;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.connect.sink.SinkRecord;
import org.apache.kafka.connect.sink.SinkTask;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Collection;
import java.util.Map;

public class RestApiSinkTask extends SinkTask {

    private String requestTopic;
    private String responseTopic;
    private String apiUrl;

    private HttpClient client = HttpClient.newHttpClient();


    @Override
    public String version() {
        return "1.0.0";
    }

    private KafkaProducer<Object,String> responseProducer;

    @Override
    public void start(Map<String, String> config) {
        requestTopic = config.get("requestTopic");
        responseTopic = config.get(RestApiSinkConnector.RESPONSE_TOPIC_CONFIG);
        apiUrl = config.get("apiUrl");


        responseProducer = new KafkaProducer(config);
    }

    private static final ObjectMapper mapper = new ObjectMapper();

    private JsonNode parseString(String s) {
        try {
            return mapper.readTree(s);
        } catch (JsonProcessingException e) {
            throw new RuntimeException(e);
        }
    }


    @FunctionalInterface
    private interface ExceptionFunction<R,E extends Exception>{
        R apply() throws E;
    }

    private static <R, E extends Exception> R unsafeRun(ExceptionFunction<R, E> function) {
        try{
            return function.apply();
        } catch (Exception e) {
            e.printStackTrace();
            throw new RuntimeException(e);
        }
    }

    @Override
    public void put(Collection<SinkRecord> records) {
        for (SinkRecord record : records) {
            if (record.value() == null) continue;
            Object value = record.value();
            System.out.println("value.getClass() = " + value.getClass().getCanonicalName());
            String requestBody = new String((byte[]) value);
            System.out.println("requestBody = " + requestBody);
            JsonNode node = unsafeRun(() -> mapper.readTree(requestBody));

            String url = node.get("url").asText();
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .build();
            String response =
                    unsafeRun(() -> client.send(request, HttpResponse.BodyHandlers.ofString())).body();
            System.out.println("response = " + response);
            ((ObjectNode) node).put("response", response);

            responseProducer.send(
                    new ProducerRecord<>(
                            responseTopic,
                            record.key() == null ? null : record.key(),
                            unsafeRun(() -> mapper.writeValueAsString(node))
                    )
            );
        }
    }

    @Override
    public void stop() {
    }
}