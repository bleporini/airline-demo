package io.confluent.ek;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.dataformat.xml.XmlMapper;
import org.apache.flink.table.annotation.DataTypeHint;
import org.apache.flink.table.functions.ScalarFunction;
import org.apache.flink.types.Row;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.stream.StreamSupport;

public class XmlToFlightInformationUDF extends ScalarFunction {
    public static final String NAME = "XML_TO_INFO";


    private final XmlMapper mapper = new XmlMapper();


    @DataTypeHint(
            "ROW<error STRING, orResult ROW<flight_number STRING, carrier STRING, departure_timestamp BIGINT, origin STRING, destination STRING, passengers ARRAY<ROW<reference STRING, name STRING, date_of_birth STRING, passport_number STRING, seat_number STRING, class STRING, deleted BOOLEAN>>>>"
    )
    public Row eval(byte[] value){
        try {
            JsonNode fi = mapper.readTree(value);
            return Row.of(
                    null,
                    Row.of(
                        fi.get("flight_number").asText(),
                        fi.get("carrier").asText(),
                        fi.get("departure_timestamp").asLong(),
                        fi.get("origin").asText(),
                        fi.get("destination").asText(),
                        passengers(fi.get("passengers"))
                    )
            );
        } catch (Exception e) {
            return Row.of(
                    stackTraceToString(e), null);
        }
    }

    private Object[] passengers(JsonNode passengers) {
        JsonNode passenger = passengers.get("passenger");
        if(passenger == null) return new Object[]{};
        if(passenger.isArray()){
            return StreamSupport.stream(passenger.spliterator(), false)
                    .map(p ->
                            Row.of(
                                    p.get("reference").asText(),
                                    p.get("name").asText(),
                                    p.get("date_of_birth") == null? "": p.get("date_of_birth").asText(),
                                    p.get("passport_number") == null? "" : p.get("passport_number").asText(),
                                    p.get("seat_number") == null ? "": p.get("seat_number").asText(),
                                    p.get("class").asText(),
                                    p.get("deleted") != null && p.get("deleted").asBoolean()
                            )
                    ).toList().toArray();
        }
        return new Row[]{
                Row.of(
                        passenger.get("reference").asText(),
                        passenger.get("name").asText(),
                        passenger.get("date_of_birth") == null? "": passenger.get("date_of_birth").asText(),
                        passenger.get("passport_number") == null? "" : passenger.get("passport_number").asText(),
                        passenger.get("seat_number") == null ? "": passenger.get("seat_number").asText(),
                        passenger.get("deleted") != null && passenger.get("deleted").asBoolean()

                )
        };
    }
    private String stackTraceToString(Exception e) {
        StringWriter sw = new StringWriter();
        PrintWriter pw = new PrintWriter(sw);
        e.printStackTrace(pw);
        return sw.toString();
    }
}