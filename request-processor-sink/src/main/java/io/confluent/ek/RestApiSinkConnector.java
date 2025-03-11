package io.confluent.ek;

import org.apache.kafka.common.config.AbstractConfig;
import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.connect.connector.Task;
import org.apache.kafka.connect.sink.SinkConnector;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class RestApiSinkConnector extends SinkConnector {

    public static final String REQUEST_TOPIC_CONFIG = "requestTopic";
    public static final String RESPONSE_TOPIC_CONFIG = "responseTopic";
    private Map<String, String> props;


    public static final String RESP_BOOTSTRAP_SERVER = "responseProducer.bootstrap.servers";
    public static final String USERNAME = "username";
    public static final String PASSWORD = "password";
    private static final ConfigDef CONFIG_DEF = new ConfigDef();
/*
    private static final ConfigDef CONFIG_DEF = new ConfigDef()
            .define(
                    RESPONSE_TOPIC_CONFIG,
                    ConfigDef.Type.STRING,
                    ConfigDef.Importance.HIGH,
                    "The Kafka topic to send responses to"
            ).define(
                    RESP_BOOTSTRAP_SERVER,
                    ConfigDef.Type.STRING,
                    ConfigDef.Importance.HIGH,
                    "The cluster to send the response"
            ).define(
                    USERNAME,
                    ConfigDef.Type.STRING,
                    ConfigDef.Importance.HIGH,
                    "Username to the Kafka cluster"
            ).define(
                    PASSWORD,
                    ConfigDef.Type.STRING,
                    ConfigDef.Importance.HIGH,
                    "Password to the Kafka cluster"
            );
*/

    @Override
    public String version() {
        return "1.0.0";
    }

    @Override
    public Class<? extends Task> taskClass() {
        return RestApiSinkTask.class;
    }

    @Override
    public List<Map<String, String>> taskConfigs(int maxTasks) {
        List<Map<String, String>> taskConfigs = new ArrayList<>();
        for (int i = 0; i < maxTasks; i++) {
            taskConfigs.add(props);
        }
        return taskConfigs;
    }

    @Override
    public ConfigDef config() {
        return CONFIG_DEF;
    }

    @Override
    public void start(Map<String, String> props) {
        System.err.println("tessssssst");
        props.forEach((k,v)-> System.out.println("k = " + k));
        this.props = props;
        AbstractConfig config = new AbstractConfig(CONFIG_DEF, props);

    }

    @Override
    public void stop() {
        // No-op
    }


}