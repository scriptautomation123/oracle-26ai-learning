package com.oracle.nudges.examples.spring;

import java.util.List;

import org.springframework.stereotype.Service;

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;

@Service
public class NudgeService {

    private final NudgeRepository repository;
    private final Tracer tracer;

    public NudgeService(NudgeRepository repository, Tracer tracer) {
        this.repository = repository;
        this.tracer = tracer;
    }

    public List<NudgeRepository.UC1Row> uc1(long customerId, int candidates) {
        Span span = tracer.spanBuilder("nudge.uc1").startSpan();
        try (var ignored = span.makeCurrent()) {
            span.setAttribute("nudge.customer_id", customerId);
            span.setAttribute("nudge.use_case", "UC1");
            span.setAttribute("nudge.candidates", candidates);
            return repository.uc1PeerProductsAndVectorRank(customerId, candidates);
        } catch (RuntimeException ex) {
            span.recordException(ex);
            span.setStatus(StatusCode.ERROR);
            throw ex;
        } finally {
            span.end();
        }
    }

    public List<NudgeRepository.UC2Row> uc2(int candidates) {
        Span span = tracer.spanBuilder("nudge.uc2").startSpan();
        try (var ignored = span.makeCurrent()) {
            span.setAttribute("nudge.use_case", "UC2");
            span.setAttribute("nudge.candidates", candidates);
            return repository.uc2AbandonedAppsAndVectorRank(candidates);
        } catch (RuntimeException ex) {
            span.recordException(ex);
            span.setStatus(StatusCode.ERROR);
            throw ex;
        } finally {
            span.end();
        }
    }

    public String uc3(long customerId, long txnId) {
        Span span = tracer.spanBuilder("nudge.uc3").startSpan();
        try (var ignored = span.makeCurrent()) {
            span.setAttribute("nudge.customer_id", customerId);
            span.setAttribute("nudge.use_case", "UC3");
            String nudge = repository.uc3GenerateNudge(customerId, txnId);
            span.setAttribute("nudge.length_chars", nudge == null ? 0 : nudge.length());
            return nudge;
        } catch (RuntimeException ex) {
            span.recordException(ex);
            span.setStatus(StatusCode.ERROR);
            throw ex;
        } finally {
            span.end();
        }
    }
}
