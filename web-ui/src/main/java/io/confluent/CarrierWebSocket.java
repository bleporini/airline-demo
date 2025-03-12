package io.confluent;//
// ========================================================================
// Copyright (c) 1995 Mort Bay Consulting Pty Ltd and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License v. 2.0 which is available at
// https://www.eclipse.org/legal/epl-2.0, or the Apache License, Version 2.0
// which is available at https://www.apache.org/licenses/LICENSE-2.0.
//
// SPDX-License-Identifier: EPL-2.0 OR Apache-2.0
// ========================================================================
//

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.confluent.AbstractTypedConsumerFactory.ConsumerRegistrator;
import io.confluent.ek.*;
import org.eclipse.jetty.websocket.api.Callback;
import org.eclipse.jetty.websocket.api.Session;
import org.eclipse.jetty.websocket.api.annotations.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;
import java.util.function.BiConsumer;
import java.util.function.Function;

@WebSocket
public class CarrierWebSocket {


    private static final Logger LOG = LoggerFactory.getLogger(CarrierWebSocket.class);
    private final ConsumerRegistrator<PassengersKeySchema, PassengersValueSchema> passengerRegistrator;
    private final ConsumerRegistrator<String, FlightInformationValueSchema> fiRegistrator;
    private final ConsumerRegistrator<byte[], byte[]> requestTopicRegistrator;
    private final ConsumerRegistrator<byte[], byte[]> responseTopicRegistrator;
    private final ConsumerRegistrator<MealsPerFlightsKeySchema, MealsPerFlightsValueSchema> requiredMealsRegistrator;
    private final ConsumerRegistrator<AlertsKeySchema, AlertsValueSchema> alertsRegistrator;
    private Session session;
    private ObjectMapper mapper = new ObjectMapper();

    public CarrierWebSocket(
            ConsumerRegistrator<PassengersKeySchema,
            PassengersValueSchema> passengerRegistrator,
            ConsumerRegistrator<String, FlightInformationValueSchema> fiRegistrator,
            ConsumerRegistrator<byte[], byte[]> requestTopicRegistrator,
            ConsumerRegistrator<byte[], byte[]> responseTopicRegistrator,
            ConsumerRegistrator<MealsPerFlightsKeySchema, MealsPerFlightsValueSchema> requiredMealsRegistrator,
            ConsumerRegistrator<AlertsKeySchema, AlertsValueSchema> alertsRegistrator) {
        this.passengerRegistrator = passengerRegistrator;
        this.fiRegistrator = fiRegistrator;
        this.requestTopicRegistrator = requestTopicRegistrator;
        this.responseTopicRegistrator = responseTopicRegistrator;
        this.requiredMealsRegistrator = requiredMealsRegistrator;
        this.alertsRegistrator = alertsRegistrator;
    }

    @OnWebSocketClose
    public void onWebSocketClose(int statusCode, String reason)
    {
        this.session = null;
        LOG.info("WebSocket Close: {} - {}", statusCode, reason);
    }

    private <K,V> BiConsumer<K,V> buildConsumer(String type, Function<K, String> keyProvider){
        return (s, f) -> {
            if (session == null) return;
            try {
                session.sendText(
                        mapper.writeValueAsString(Map.of(type, Map.of(keyProvider.apply(s), f))),
                        Callback.NOOP
                );
            } catch (JsonProcessingException e) {
                throw new RuntimeException(e);
            }
        };
    }
    @OnWebSocketOpen
    public void onWebSocketOpen(Session session) {
        this.session = session;
        LOG.info("WebSocket Open: {}", session);
        this.session.sendText("You are now connected to " + this.getClass().getName(), Callback.NOOP);
        passengerRegistrator.register(this.<PassengersKeySchema, PassengersValueSchema>buildConsumer("passenger", PassengersKeySchema::getKey));
        fiRegistrator.register(buildConsumer("flight_information", (s) -> s));
        requestTopicRegistrator.register(this.buildConsumer("request", String::new));
        responseTopicRegistrator.register(this.buildConsumer("response", String::new));
        requiredMealsRegistrator.register(this.buildConsumer("required_meals", MealsPerFlightsKeySchema::getKey));
        alertsRegistrator.register(this.buildConsumer("alerts", k -> k.getKey().toString()));
    }

    @OnWebSocketError
    public void onWebSocketError(Throwable cause) {
        LOG.warn("WebSocket Error",cause);
    }

    @OnWebSocketMessage
    public void onWebSocketText(String message) {
        LOG.info("Message received: {}", message);

    }
}
