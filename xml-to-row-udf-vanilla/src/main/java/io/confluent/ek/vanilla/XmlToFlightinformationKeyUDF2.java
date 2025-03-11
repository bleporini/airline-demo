package io.confluent.ek.vanilla;

import org.apache.flink.table.functions.ScalarFunction;

import javax.xml.stream.XMLEventReader;
import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.events.StartElement;
import javax.xml.stream.events.XMLEvent;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.text.DecimalFormat;
import java.util.HashMap;
import java.util.Map;

public class XmlToFlightinformationKeyUDF2 extends ScalarFunction {
    public static final String NAME = "XML_TO_KEY";

    public String eval(byte[] value) {
        try {
            return extractKeyFromXml(value);
        } catch (Exception e) {
            return "Key extraction failed: " + e.getMessage();
        }
    }

    private String extractKeyFromXml(byte[] value) throws Exception {
        ByteArrayInputStream inputStream = new ByteArrayInputStream(value);
        XMLInputFactory inputFactory = XMLInputFactory.newInstance();
        XMLEventReader reader = inputFactory.createXMLEventReader(inputStream);

        Map<String, String> flightInfo = new HashMap<>();
        String currentElement = "";

        while (reader.hasNext()) {
            XMLEvent event = reader.nextEvent();

            if (event.isStartElement()) {
                StartElement startElement = event.asStartElement();
                currentElement = startElement.getName().getLocalPart();
            } else if (event.isCharacters() && !event.asCharacters().isWhiteSpace()) {
                flightInfo.put(currentElement, event.asCharacters().getData());
            }
        }

        String flightNumber = flightInfo.getOrDefault("flight_number", "");
        String carrier = flightInfo.getOrDefault("carrier", "");
        String departureTimestamp = flightInfo.getOrDefault("departure_timestamp", "");
        String origin = flightInfo.getOrDefault("origin", "");

        return flightNumber + "_" + carrier + "_" + departureTimestamp + "_" + origin;
    }
}