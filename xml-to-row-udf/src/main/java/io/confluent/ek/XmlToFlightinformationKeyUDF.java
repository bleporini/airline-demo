package io.confluent.ek;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.dataformat.xml.XmlMapper;
import org.apache.flink.table.functions.ScalarFunction;

import java.text.DecimalFormat;

public class XmlToFlightinformationKeyUDF extends ScalarFunction {
    public static final String NAME = "XML_TO_KEY";


    private final XmlMapper mapper = new XmlMapper();
    private final DecimalFormat df = new DecimalFormat("###");

    public String eval(byte[] value) {
        JsonNode fi;

        try {
            fi = mapper.readTree(value);
        } catch (Exception e) {
            return "Key extraction failed: " + e.getMessage();
        }

        return fi==null?
                "null":
                fi.get("flight_number").asText() + "_" + fi.get("carrier").asText() + "_" +
                fi.get("departure_timestamp").asLong() +"_" +fi.get("origin").asText();

    }
}