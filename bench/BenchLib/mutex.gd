@tool

# I have the feeling I can replace a lot of this with a Semaphore
# class Barrier {
class Barrier:
#  public:
#   Barrier(int num_threads) : running_threads_(num_threads) {}
	func _init( num_threads:int ) -> void:
		running_threads_ = num_threads
#
	# Called by each thread
#   bool wait() EXCLUDES(lock_) {
	func wait() -> bool:
#     bool last_thread = false;
		var last_thread:bool = false
#     {
#       MutexLock ml(lock_);
		# NOTE: The MutexLock above is a wrapper for unique_lock
		# the lock is constructed, and locked, or we wait.
		lock_.lock()
#       last_thread = createBarrier(ml);
		last_thread = await createBarrier(lock_) # FIXME no signals.
		# NOTE: the lock is unlocked inside the create barrier call while
		# we wait for the phase condition signa.
#     }
#     if (last_thread) phase_condition_.notify_all();
		if last_thread: phase_condition_.emit() # FIXME I cant use a signal here
#     return last_thread;
		return last_thread
#   }

#   void removeThread() EXCLUDES(lock_) {
	func removeThread() -> void:
#     MutexLock ml(lock_);
		lock_.lock() # NOTE: Again no Scoped Lock Primitive
#     --running_threads_;
		running_threads_ -= 1
#     if (entered_ != 0) phase_condition_.notify_all();
		if entered_ != 0: phase_condition_.emit()
		lock_.unlock() # Manually unlocking
#   }

#  private:
#   Mutex lock_;
	var lock_ := Mutex.new()
#   Condition phase_condition_;
	signal phase_condition_
#   int running_threads_;
	var running_threads_:int

	# State for barrier management
#   int phase_number_ = 0;
	var phase_number_:int = 0
#   int entered_ = 0;  // Number of threads that have entered this barrier
	var entered_:int = 0

	# Enter the barrier and wait until all other threads have also
	# entered the barrier. Returns iff this is the last thread to
	# enter the barrier.
#   bool createBarrier(MutexLock& ml) REQUIRES(lock_) {
	func createBarrier( ml:Mutex ) -> bool:
#     BM_CHECK_LT(entered_, running_threads_);
		assert(entered_ < running_threads_)
#     entered_++;
		entered_ += 1
#     if (entered_ < running_threads_) {
		if entered_ < running_threads_:
			# Wait for all threads to enter
#       int phase_number_cp = phase_number_;
			var phase_number_cp:int = phase_number_
#       auto cb = [this, phase_number_cp]() {
#         return this->phase_number_ > phase_number_cp ||
#                entered_ == running_threads_;  // A thread has aborted in error
#       };
			var cb:Callable = func() -> bool:
					return phase_number_ > phase_number_cp \
					or entered_ == running_threads_
#       phase_condition_.wait(ml.native_handle(), cb);
			#FIXME This is the part I am hung up on. cpp documentation
			# on condition_variable.wait() says that the lock is unlocked here
			# and then a signal is waited on which would look something like:
			ml.unlock() # allows another thread to reach this point.
			while not cb.call():
				#print("await phase_condition")
				await phase_condition_
				#print("post await phase_condition")
#       if (phase_number_ > phase_number_cp) return false;
			if phase_number_ > phase_number_cp: return false
		# else (running_threads_ == entered_) and we are the last thread.
#     }
		#print("last_thread")
		# Last thread has reached the barrier
#     phase_number_++;
		phase_number_ += 1
#     entered_ = 0;
		entered_ = 0
#     return true;
		return true
#   }
# };
