module OLAScheduling
  
  SCHEDULER_USER = User.first
  
  # redundant definitions from OLAConstants required to get around precondition limitations
  BATCH_SIZE = 2
  KIT_KEY = :kit

  # used in place of returning true in precondition
  # sets operation to pending
  # then, if there is enough fellow pending operations, batches them into a job and schedule.
  def schedule_ops_of_type_if_enough(op, batch_size)
    if op.plan.nil? # don't perform computation in testing mode with no plan
      return
    end
    operations = Operation.where({operation_type_id: op.operation_type_id, status: ["pending"]})
    op.status = "pending"
    op.save
    operations << op
    operations = operations.to_a.uniq
    
    op_batches = operations.each_slice(batch_size).to_a
    op_batches.each do |ops|
      if ops.length >= batch_size
        Job.schedule(
          operations: ops,
          user: SCHEDULER_USER
        )
      end
    end
    exit
  end
  
  # used in place of returning true in precondition
  # gathers together all the other ops with the same kit
  # and schedules them together if they are all ready
  # looks at this_op.inputs[0].item.get(KIT_KEY) to decide what kit an op belongs
  # 
  def schedule_same_kit_ops(this_op)
    if this_op.plan.nil? # don't perform computation in testing mode with no plan
      return
    end
    
    kit_id = this_op.inputs[0].item.get(KIT_KEY)
    
    if kit_id.nil?
          this_op.error(:no_kit, "This operation did not have an associated kit id in its input and so couldn't be batched")
      exit
    end
    
    operations = Operation.where({operation_type_id: this_op.operation_type_id, status: ["pending"]})
    this_op.status = "pending"
    this_op.save
    operations << this_op
    operations = operations.to_a.uniq
    operations = operations.select do |op|
      op.inputs[0].item.get(KIT_KEY)
    end
    if operations.length == BATCH_SIZE
      Job.schedule(
        operations: operations,
        user: SCHEDULER_USER
      )
    elsif operations.length > BATCH_SIZE
      operations.each do |op|
        op.error(:batch_too_big, "There are too many samples being run with kit #{kit_id}. The Batch size is set to #{BATCH_SIZE}, but there are #{operations.length} operations which list #{kit_id} as their kit association.")
        op.save
        op.plan.error("There are too many samples being run with kit #{kit_id}. The Batch size is set to #{BATCH_SIZE}, but there are #{operations.length} operations which list #{kit_id} as their kit association.", :batch_too_big)
        op.plan.save
      end
    end
    exit
  end
end