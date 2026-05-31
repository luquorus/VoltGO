package com.example.evstation.batteryswap.config;

import com.example.evstation.auth.infrastructure.security.JwtAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import com.example.evstation.batteryswap.application.BatterySwapWebSocketHandler;
import com.example.evstation.batteryswap.application.SimulatorDisplayWebSocketHandler;

@Slf4j
@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class BatterySwapWebSocketConfig implements WebSocketConfigurer {

    private final BatterySwapWebSocketHandler batterySwapWebSocketHandler;
    private final SimulatorDisplayWebSocketHandler simulatorDisplayWebSocketHandler;

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        // Authenticated WebSocket for admin/operator actions
        registry.addHandler(batterySwapWebSocketHandler, "/ws/battery-swap")
                .setAllowedOriginPatterns("*");

        // Public WebSocket for station display (no auth required)
        registry.addHandler(simulatorDisplayWebSocketHandler, "/ws/display/battery-swap")
                .setAllowedOriginPatterns("*");
    }
}
