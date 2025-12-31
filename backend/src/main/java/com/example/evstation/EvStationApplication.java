package com.example.evstation;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;

@SpringBootApplication(exclude = {UserDetailsServiceAutoConfiguration.class})
public class EvStationApplication {

    public static void main(String[] args) {
        SpringApplication.run(EvStationApplication.class, args);
    }
}

