package io.confluent.ek;

import org.junit.jupiter.api.Test;

import java.io.IOException;

import static org.junit.jupiter.api.Assertions.*;


class XmlToFlightinformationKeyUDFTest {
private static String payload="<flight><flight_number>FL123</flight_number><carrier>EK</carrier><departure_timestamp>1703126400</departure_timestamp><origin>OMDB</origin><destination>EGLL</destination><passengers><passenger><reference>REF1019</reference><name>Ava Singh</name><date_of_birth>1974-10-21</date_of_birth><passport_number></passport_number><seat_number>39A</seat_number><class>premium</class><deleted>false</deleted></passenger></passengers></flight>";

    @Test
    void smoke() throws IOException {
        String key = new XmlToFlightinformationKeyUDF().eval(payload.getBytes());
        System.out.println("key = " + key);
    }
}