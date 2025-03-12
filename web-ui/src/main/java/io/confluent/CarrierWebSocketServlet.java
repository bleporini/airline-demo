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

import io.confluent.AbstractTypedConsumerFactory.ConsumerRegistrator;
import io.confluent.ek.*;
import org.eclipse.jetty.ee10.websocket.server.*;

import java.time.Duration;

@SuppressWarnings("serial")
public class CarrierWebSocketServlet extends JettyWebSocketServlet
{
    private final ConsumerRegistrator<PassengersKeySchema, PassengersValueSchema> passengerRegistrator;
    private final ConsumerRegistrator<String, FlightInformationValueSchema> fiRegistrator;
    private final ConsumerRegistrator<byte[], byte[]> requestTopicRegistrator;
    private final ConsumerRegistrator<byte[], byte[]> responseTopicRegistrator;
    private final ConsumerRegistrator<MealsPerFlightsKeySchema, MealsPerFlightsValueSchema> requiredMealsRegistrator;
    private final ConsumerRegistrator<AlertsKeySchema, AlertsValueSchema> alertsRegistrator;

    public CarrierWebSocketServlet(
            ConsumerRegistrator<PassengersKeySchema, PassengersValueSchema> passengerRegistrator,
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

    @Override
    public void configure(JettyWebSocketServletFactory factory)
    {
        factory.setIdleTimeout(Duration.ofDays(1));
        factory.setCreator((req, resp) ->
                new CarrierWebSocket(
                        passengerRegistrator,
                        fiRegistrator,
                        requestTopicRegistrator,
                        responseTopicRegistrator,
                        requiredMealsRegistrator,
                        alertsRegistrator)
        );
    }
}