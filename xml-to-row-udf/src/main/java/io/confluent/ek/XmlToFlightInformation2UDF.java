package io.confluent.ek;

import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamConstants;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamReader;
import org.apache.flink.table.annotation.DataTypeHint;
import org.apache.flink.table.functions.ScalarFunction;
import org.apache.flink.types.Row;

import java.io.ByteArrayInputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.List;

public class XmlToFlightInformation2UDF extends ScalarFunction {
    public static final String NAME = "XML_TO_INFO";

    @DataTypeHint(
            "ROW<error STRING, orResult ROW<flight_number STRING, carrier STRING, departure_timestamp BIGINT, origin STRING, destination STRING, passengers ARRAY<ROW<reference STRING, name STRING, date_of_birth STRING, passport_number STRING, seat_number STRING, class STRING, deleted BOOLEAN>>>>"
    )
    public Row eval(byte[] value) throws XMLStreamException {
        try (var bais = new ByteArrayInputStream(value)) {
            XMLStreamReader reader = XMLInputFactory.newInstance().createXMLStreamReader(bais);
            return parseFlightInformation(reader);
        } catch (Exception e) {
            return Row.of(stackTraceToString(e), null);
        }
    }

    private Row parseFlightInformation(XMLStreamReader reader) throws XMLStreamException {
        String flightNumber = null;
        String carrier = null;
        Long departureTimestamp = null;
        String origin = null;
        String destination = null;
        List<Row> passengers = new ArrayList<>();

        while (reader.hasNext()) {
            int eventType = reader.next();
            if (eventType == XMLStreamConstants.START_ELEMENT) {
                switch (reader.getLocalName()) {
                    case "flight_number": flightNumber = reader.getElementText(); break;
                    case "carrier": carrier = reader.getElementText(); break;
                    case "departure_timestamp": departureTimestamp = parseLong(reader); break;
                    case "origin": origin = reader.getElementText(); break;
                    case "destination": destination = reader.getElementText(); break;
                    case "passengers": passengers = parsePassengers(reader); break;
                }
            } else if (
                    eventType == XMLStreamConstants.END_ELEMENT &&
                    "flight".equals(reader.getLocalName())) {
                return Row.of(null, Row.of(flightNumber, carrier, departureTimestamp, origin, destination, passengers));
            }

        }
        return Row.of("Flight information not found", null);
    }

    private List<Row> parsePassengers(XMLStreamReader reader) throws XMLStreamException {
        List<Row> passengers = new ArrayList<>();
        while (reader.hasNext()) {
            int eventType = reader.next();
            if (eventType == XMLStreamConstants.START_ELEMENT && "passenger".equals(reader.getLocalName())) {
                passengers.add(parsePassenger(reader));
            } else if (eventType == XMLStreamConstants.END_ELEMENT && "passengers".equals(reader.getLocalName())) {
                return passengers;
            }
        }
        return passengers;
    }

    private Row parsePassenger(XMLStreamReader reader) throws XMLStreamException {
        String reference = null;
        String name = null;
        String dateOfBirth = null;
        String passportNumber = null;
        String seatNumber = null;
        String clazz = null;
        Boolean deleted = null;

        while (reader.hasNext()) {
            int eventType = reader.next();
            if (eventType == XMLStreamConstants.START_ELEMENT) {
                switch (reader.getLocalName()) {
                    case "reference": reference = reader.getElementText(); break;
                    case "name": name = reader.getElementText(); break;
                    case "date_of_birth": dateOfBirth = reader.getElementText(); break;
                    case "passport_number": passportNumber = reader.getElementText(); break;
                    case "seat_number": seatNumber = reader.getElementText(); break;
                    case "class": clazz = reader.getElementText(); break;
                    case "deleted": deleted = parseBoolean(reader); break;
                }
            } else if (eventType == XMLStreamConstants.END_ELEMENT && "passenger".equals(reader.getLocalName())) {
                return Row.of(reference, name, dateOfBirth, passportNumber, seatNumber, clazz, deleted);
            }
        }
        return null; // or throw an exception if a passenger is malformed
    }

    private Long parseLong(XMLStreamReader reader) throws XMLStreamException {
        String value = reader.getElementText();
        return value == null ? null : Long.parseLong(value);
    }

    private Boolean parseBoolean(XMLStreamReader reader) throws XMLStreamException {
        String value = reader.getElementText();
        return value == null ? null : Boolean.parseBoolean(value);
    }


    private String stackTraceToString(Exception e) {
        StringWriter sw = new StringWriter();
        PrintWriter pw = new PrintWriter(sw);
        e.printStackTrace(pw);
        return sw.toString();
    }
}