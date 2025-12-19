output "run_queue_url" {
  value = aws_sqs_queue.run_queue.id
}

output "step_queue_url" {
  value = aws_sqs_queue.step_queue.id
}

output "retry_queue_url" {
  value = aws_sqs_queue.retry_queue.id
}

output "db_endpoint" {
  value = aws_db_instance.postgres.address
}
