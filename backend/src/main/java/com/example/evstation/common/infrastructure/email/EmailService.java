package com.example.evstation.common.infrastructure.email;

import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

/**
 * Email Service for sending notifications via SMTP.
 * Falls back to console logging if SMTP is not configured.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class EmailService {

    private final JavaMailSender javaMailSender;

    @Value("${spring.mail.username:}")
    private String fromEmail;

    @Value("${app.email.enabled:false}")
    private boolean emailEnabled;

    @Value("${app.email.from-name:VoltGo}")
    private String fromName;

    /**
     * Send an email asynchronously.
     * Logs to console if SMTP is not enabled.
     */
    @Async
    public void sendEmail(String to, String subject, String body) {
        if (!emailEnabled) {
            logEmail(to, subject, body);
            return;
        }

        try {
            MimeMessage message = javaMailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setFrom(fromEmail, fromName);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(buildHtmlEmail(body), true);

            javaMailSender.send(message);
            log.info("Email sent: to={}, subject={}", to, subject);

        } catch (Exception e) {
            log.error("Failed to send email to {}: {}", to, e.getMessage());
            logEmail(to, subject, body);
        }
    }

    /**
     * Send email synchronously.
     */
    public void sendEmailSync(String to, String subject, String body) {
        if (!emailEnabled) {
            logEmail(to, subject, body);
            return;
        }

        try {
            MimeMessage message = javaMailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setFrom(fromEmail, fromName);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(buildHtmlEmail(body), true);

            javaMailSender.send(message);
            log.info("Email sent: to={}, subject={}", to, subject);

        } catch (Exception e) {
            log.error("Failed to send email to {}: {}", to, e.getMessage());
            logEmail(to, subject, body);
        }
    }

    private void logEmail(String to, String subject, String body) {
        System.out.println("========================================");
        System.out.println("📧 EMAIL TO: " + to);
        System.out.println("📧 SUBJECT: " + subject);
        System.out.println("📧 BODY:");
        System.out.println(body);
        System.out.println("========================================");
        log.info("Email logged: to={}, subject={}", to, subject);
    }

    private String buildHtmlEmail(String body) {
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                    .header { background: #2E7D32; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
                    .header h1 { margin: 0; font-size: 24px; }
                    .content { background: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px; }
                    .footer { text-align: center; padding: 10px; color: #888; font-size: 12px; }
                    .divider { border-top: 1px solid #ddd; margin: 15px 0; }
                    p { margin: 0 0 12px 0; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>VoltGo</h1>
                    </div>
                    <div class="content">
                        %s
                    </div>
                    <div class="footer">
                        <div class="divider"></div>
                        <p>This is an automated message from VoltGo. Please do not reply to this email.</p>
                    </div>
                </div>
            </body>
            </html>
            """.formatted(body.replace("\n", "<br>"));
    }
}
