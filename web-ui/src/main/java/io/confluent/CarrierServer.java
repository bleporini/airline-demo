package io.confluent;//

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.confluent.AbstractTypedConsumerFactory.ConsumerRegistrator;
import io.confluent.AbstractTypedConsumerFactory.TypedConsumerFactory;
import io.confluent.ek.*;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.eclipse.jetty.ee10.servlet.DefaultServlet;
import org.eclipse.jetty.ee10.servlet.ServletContextHandler;
import org.eclipse.jetty.ee10.servlet.ServletHolder;
import org.eclipse.jetty.ee10.websocket.server.config.JettyWebSocketServletContainerInitializer;
import org.eclipse.jetty.server.Server;

import java.io.*;
import java.net.URL;
import java.util.Objects;
import java.util.Properties;

import static io.confluent.AbstractTypedConsumerFactory.*;

public class CarrierServer
{

    private static Properties loadConfig(InputStream propsIS) throws IOException {
        Properties props = new Properties();
        props.load(propsIS);
        return props;
    }

    private static Properties loadProperties(String propertiesPath) {
        try (InputStream propsIS = CarrierServer.class.getResourceAsStream(propertiesPath)) {
            return loadConfig(propsIS);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }

    }

    public static void main(String[] args) throws Exception
    {
        String propertiesPath = "/cc.properties";
        Properties properties = loadProperties(propertiesPath);
        TypedConsumerFactory consumerFactory = configureFactory(propertiesPath);
        var passengerRegistrator = consumerFactory.buildPassengerConsumer();
        var fiRegistrator = consumerFactory.buildFlightInfoConsumer();
        var requestTopicRegistrator = consumerFactory.buildRequestTopicConsumer();
        var responseTopicRegistrator = consumerFactory.buildResponseTopicConsumer(properties.getProperty("passport_responses.topic"));
        Server server = CarrierServer.newServer(
                8080,
                new FlightInformationProducer(properties),
                passengerRegistrator,
                fiRegistrator,
                requestTopicRegistrator,
                responseTopicRegistrator,
                consumerFactory.buildRequiredMealsTopicConsumer(),
                consumerFactory.buildAlertTopicConsumer());
        server.start();
        server.join();

    }

    private static ObjectMapper mapper = new ObjectMapper();

    public static Server newServer(int port,
                                   FlightInformationProducer producer,
                                   ConsumerRegistrator<PassengersKeySchema, PassengersValueSchema> passengerRegistrator,
                                   ConsumerRegistrator<String, FlightInformationValueSchema> fiRegistrator,
                                   ConsumerRegistrator<RequestTopicKeySchema, byte[]> requestTopicRegistrator,
                                   ConsumerRegistrator<ResponseTopicKeySchema, byte[]> responseTopicRegistrator,
                                   ConsumerRegistrator<MealsPerFlightsKeySchema, MealsPerFlightsValueSchema>requiredMealsRegistrator,
                                   ConsumerRegistrator<AlertsKeySchema, AlertsValueSchema> alertsConsumerRegistrator) {
        Server server = new Server(port);

        ServletContextHandler context = new ServletContextHandler(ServletContextHandler.SESSIONS);
        context.setContextPath("/");
        server.setHandler(context);

        // Add websocket servlet
        JettyWebSocketServletContainerInitializer.configure(context, null);
        ServletHolder wsHolder = new ServletHolder(
                "stations",
                new CarrierWebSocketServlet(
                        passengerRegistrator,
                        fiRegistrator,
                        requestTopicRegistrator,
                        responseTopicRegistrator,
                        requiredMealsRegistrator,
                        alertsConsumerRegistrator
                )
        );
        context.addServlet(wsHolder, "/flights");

        URL urlStatics = Thread.currentThread().getContextClassLoader().getResource("static/index.html");
        Objects.requireNonNull(urlStatics, "Unable to find index.html in classpath");
        String urlBase = urlStatics.toExternalForm().replaceFirst("/[^/]*$", "/");
        ServletHolder defHolder = new ServletHolder("default", new DefaultServlet());
        defHolder.setInitParameter("resourceBase", urlBase);
        defHolder.setInitParameter("dirAllowed", "true");
        context.addServlet(defHolder, "/");

        context.addServlet(new HttpServlet() {
            @Override
            protected void doGet(HttpServletRequest req, HttpServletResponse response) throws ServletException, IOException {
                response.setContentType("application/json");

                try (InputStream inputStream = CarrierServer.class.getResourceAsStream("/sample.json");
                     BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {

                    StringBuilder jsonString = new StringBuilder();
                    String line;
                    while ((line = reader.readLine()) != null) {
                        jsonString.append(line);
                    }

                    PrintWriter out = response.getWriter();
                    out.print(jsonString);
                    out.flush();
                }
            }
        }, "/sample");

        context.addServlet(new HttpServlet() {
            @Override
            protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
                String flightId = req.getHeader("flight_id");
                String ct = req.getHeader("content-type");
                System.out.println("ct = " + ct);
                try (ServletInputStream is = req.getInputStream()) {
                    if("application/json".equals(ct)){
                        FlightInformationValueSchema fi = mapper.readValue(is, FlightInformationValueSchema.class);
                        producer.send(flightId, fi);
                    } else if ("application/xml".equals(ct)) {
                        producer.send(flightId, is.readAllBytes());
                    }
                }
            }
        }, "/flight-information");

        context.addServlet(new HttpServlet() {
            @Override
            protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
                String flightId = req.getHeader("flight_id");
                CheckinOpenEventsValueSchema checkinOpenEventsValue = new CheckinOpenEventsValueSchema();
                checkinOpenEventsValue.setEventName("checkin-open");
                producer.send(flightId, checkinOpenEventsValue);
            }
        }, "/check-in-open");

        context.addServlet(new HttpServlet() {
            @Override
            protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
                String flightId = req.getHeader("flight_id");
                try (ServletInputStream is = req.getInputStream()) {
                    JsonNode json = mapper.readValue(is, JsonNode.class);
                    CmsEventValueSchema cmsEvent = new CmsEventValueSchema();
                    cmsEvent.setBusinessMeals(
                        json.get("business_meals").asInt()
                    );
                    cmsEvent.setEconomyMeals(
                            json.get("economy_meals").asInt()
                    );
                    cmsEvent.setFirstMeals(
                            json.get("first_meals").asInt()
                    );
                    cmsEvent.setPremiumMeals(
                            json.get("premium_meals").asInt()
                    );
                    producer.send(flightId, cmsEvent);
                }
            }
        }, "/cms-event");

        return server;
    }
}
