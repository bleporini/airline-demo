package io.confluent.ek;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.xml.XmlMapper;
import org.apache.flink.table.functions.ScalarFunction;

import java.io.IOException;

public class XmlToFlightJsonStringUDF extends ScalarFunction {
    public static final String NAME = "XML_TO_JSON";


    private final XmlMapper mapper = new XmlMapper();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public String eval(byte[] value)  {
        try {
            JsonNode fi = mapper.readTree(value);
            return objectMapper.writeValueAsString(fi);
        } catch (IOException e) {
            return "Error during JSON parsing: " + e.getMessage();
        }


    }
}