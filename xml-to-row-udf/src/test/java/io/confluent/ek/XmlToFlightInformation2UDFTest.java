package io.confluent.ek;

import org.apache.flink.types.Row;
import org.junit.jupiter.api.Test;

import javax.xml.stream.XMLStreamException;

class XmlToFlightInformation2UDFTest {

    String payload = "<flight>\n" +
                     "    <flight_number>FL123</flight_number>\n" +
                     "    <carrier>EK</carrier>\n" +
                     "    <departure_timestamp>1703126400</departure_timestamp>\n" +
                     "    <origin>OMDB</origin>\n" +
                     "    <destination>EGLL</destination>\n" +
                     "    <passengers>\n" +
                     "        <passenger>\n" +
                     "            <reference>REF1019</reference>\n" +
                     "            <name>Ava Singh</name>\n" +
                     "            <date_of_birth>1974-10-21</date_of_birth>\n" +
                     "            <passport_number></passport_number>\n" +
                     "            <seat_number>39A</seat_number>\n" +
                     "            <class>premium</class>\n" +
                     "            <deleted>false</deleted>\n" +
                     "        </passenger>\n" +
                     "        <passenger>\n" +
                     "            <reference>REF1020</reference>\n" +
                     "            <name>Ethan Wang</name>\n" +
                     "            <date_of_birth>1990-07-07</date_of_birth>\n" +
                     "            <passport_number></passport_number>\n" +
                     "            <seat_number>40B</seat_number>\n" +
                     "            <class>economy</class>\n" +
                     "            <deleted>false</deleted>\n" +
                     "        </passenger>\n" +
                     "        <passenger>\n" +
                     "            <reference>REF1021</reference>\n" +
                     "            <name>Sophia Patel</name>\n" +
                     "            <date_of_birth>1971-04-28</date_of_birth>\n" +
                     "            <passport_number></passport_number>\n" +
                     "            <seat_number>41A</seat_number>\n" +
                     "            <class>first</class>\n" +
                     "            <deleted>false</deleted>\n" +
                     "        </passenger>\n" +
                     "        <passenger>\n" +
                     "            <reference>REF1022</reference>\n" +
                     "            <name>David Lee</name>\n" +
                     "            <date_of_birth>1992-01-13</date_of_birth>\n" +
                     "            <passport_number></passport_number>\n" +
                     "            <seat_number>42B</seat_number>\n" +
                     "            <class>economy</class>\n" +
                     "            <deleted>false</deleted>\n" +
                     "        </passenger>\n" +
                     "        <passenger>\n" +
                     "            <reference>REF1023</reference>\n" +
                     "            <name>Maria Rodriguez</name>\n" +
                     "            <date_of_birth>1979-08-20</date_of_birth>\n" +
                     "            <passport_number></passport_number>\n" +
                     "            <seat_number>43A</seat_number>\n" +
                     "            <class>economy</class>\n" +
                     "            <deleted>false</deleted>\n" +
                     "        </passenger>\n" +
                     "        <passenger>\n" +
                     "            <reference>REF1024</reference>\n" +
                     "            <name>Ahmed Ali</name>\n" +
                     "            <date_of_birth>1995-05-06</date_of_birth>\n" +
                     "            <passport_number></passport_number>\n" +
                     "            <seat_number>44B</seat_number>\n" +
                     "            <class>business</class>\n" +
                     "            <deleted>false</deleted>\n" +
                     "        </passenger>\n" +
                     "        <passenger>\n" +
                     "            <reference>REF1025</reference>\n" +
                     "            <name>Emily Johnson</name>\n" +
                     "            <date_of_birth>1972-02-03</date_of_birth>\n" +
                     "            <passport_number></passport_number>\n" +
                     "            <seat_number>45A</seat_number>\n" +
                     "            <class>economy</class>\n" +
                     "            <deleted>false</deleted>\n" +
                     "        </passenger>\n" +
                     "        <passenger>\n" +
                     "            <reference>REF1026</reference>\n" +
                     "            <name>Benjamin Chen</name>\n" +
                     "            <date_of_birth>1993-09-19</date_of_birth>\n" +
                     "            <passport_number></passport_number>\n" +
                     "            <seat_number>46B</seat_number>\n" +
                     "            <class>economy</class>\n" +
                     "            <deleted>false</deleted>\n" +
                     "        </passenger>\n" +
                     "        <passenger>\n" +
                     "            <reference>REF1027</reference>\n" +
                     "            <name>Isabella Nguyen</name>\n" +
                     "            <date_of_birth>1970-06-11</date_of_birth>\n" +
                     "            <passport_number></passport_number>\n" +
                     "            <seat_number>47A</seat_number>\n" +
                     "            <class>economy</class>\n" +
                     "            <deleted>false</deleted>\n" +
                     "        </passenger>\n" +
                     "        <passenger>\n" +
                     "            <reference>REF1028</reference>\n" +
                     "            <name>Oliver Kim</name>\n" +
                     "            <date_of_birth>1996-03-26</date_of_birth>\n" +
                     "            <passport_number></passport_number>\n" +
                     "            <seat_number>48B</seat_number>\n" +
                     "            <class>premium</class>\n" +
                     "            <deleted>false</deleted>\n" +
                     "        </passenger>\n" +
                     "    </passengers>\n" +
                     "</flight>\n";

    @Test
    void smoke() throws XMLStreamException {
        System.out.println("payload = " + payload);
        var flightinformation = new XmlToFlightInformation2UDF().eval(payload.getBytes());
        System.out.println("flightinformation = " + flightinformation);
    }
    @Test
    void smoke2() throws XMLStreamException {
        Row flightinformation = new XmlToFlightInformation2UDF().eval("<flight><flight_number>FL123</flight_number><carrier>EK</carrier><departure_timestamp>1703126400</departure_timestamp><origin>OMDB</origin><destination>EGLL</destination><passengers><passenger><reference>REF1019</reference><name>Ava Singh</name><date_of_birth>1974-10-21</date_of_birth><passport_number></passport_number><seat_number>39A</seat_number><class>premium</class><deleted>false</deleted></passenger></passengers></flight>".getBytes());
        System.out.println("flightinformation = " + flightinformation);
        if (flightinformation.getField(1) == null) throw new NullPointerException();
//        if(flightinformation.getField(0) != null) throw new RuntimeException("Error found");
    }
}