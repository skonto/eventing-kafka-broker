#!/usr/bin/env bash

source $(dirname $0)/e2e-common.sh

if ! ${SKIP_INITIALIZE}; then
  initialize $@ --skip-istio-addon
  save_release_artifacts || fail_test "Failed to save release artifacts"
fi

if ! ${LOCAL_DEVELOPMENT}; then
  scale_controlplane kafka-controller kafka-webhook-eventing eventing-webhook eventing-controller
  apply_sacura || fail_test "Failed to apply Sacura"
  apply_chaos || fail_test "Failed to apply chaos"
fi

header "Waiting Knative eventing to come up"

wait_until_pods_running knative-eventing || fail_test "Pods in knative-eventing didn't come up"

header "Running tests"

export_logs_continuously

go_test_e2e -timeout=30m ./test/e2e/... -channels=messaging.knative.dev/v1beta1:KafkaChannel || fail_test "E2E suite failed"

go_test_e2e -tags=deletecm ./test/e2e/... -channels=messaging.knative.dev/v1beta1:KafkaChannel || fail_test "E2E (deletecm) suite failed"

if ! ${LOCAL_DEVELOPMENT}; then
  go_test_e2e -tags=sacura -timeout=40m ./test/e2e/... || fail_test "E2E (sacura) suite failed"
fi

success
