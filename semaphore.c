#include <stdbool.h>
#include <fcntl.h>           /* For O_* constants */
#include <sys/stat.h>        /* For mode constants */
#include <semaphore.h>
#include <ruby.h>

void Init_semaphore(void);
VALUE semaphore_initialize(VALUE, VALUE, VALUE);
VALUE semaphore_post(VALUE);
VALUE semaphore_wait(VALUE);
VALUE semaphore_trywait(VALUE);
#ifdef HAVE_SEM_TIMEDWAIT
VALUE semaphore_timedwait(VALUE, VALUE);
#endif
VALUE semaphore_close(VALUE);
VALUE semaphore_unlink(VALUE);
VALUE semaphore_getvalue(VALUE);

void Init_semaphore()
{
	VALUE rb_mMultiProcessing;
	VALUE rb_cSemaphore;

	rb_mMultiProcessing = rb_define_module("MultiProcessing");
	rb_cSemaphore = rb_define_class_under(rb_mMultiProcessing, "Semaphore", rb_cObject);

	rb_define_method(rb_cSemaphore, "initialize", semaphore_initialize, 2);
	rb_define_alias(rb_cSemaphore, "open", "initialize");

	rb_define_method(rb_cSemaphore, "post", semaphore_post, 0);
	rb_define_alias(rb_cSemaphore, "V", "post");
	rb_define_alias(rb_cSemaphore, "signal", "post");
	rb_define_alias(rb_cSemaphore, "unlock", "post");

	rb_define_method(rb_cSemaphore, "wait", semaphore_wait, 0);
	rb_define_alias(rb_cSemaphore, "P", "wait");
	rb_define_alias(rb_cSemaphore, "lock", "wait");

	rb_define_method(rb_cSemaphore, "trywait", semaphore_trywait, 0);
	rb_define_alias(rb_cSemaphore, "tryP", "trywait");
	rb_define_alias(rb_cSemaphore, "trylock", "trywait");

#ifdef HAVE_SEM_TIMEDWAIT
	rb_define_method(rb_cSemaphore, "timedwait", semaphore_timedwait, 1);
	rb_define_alias(rb_cSemaphore, "timedP", "timedwait");
	rb_define_alias(rb_cSemaphore, "timedlock", "timedwait");
#endif

	rb_define_method(rb_cSemaphore, "close", semaphore_close, 0);
	rb_define_method(rb_cSemaphore, "unlink", semaphore_unlink, 0);
	rb_define_method(rb_cSemaphore, "getvalue", semaphore_getvalue, 0);
	rb_define_alias(rb_cSemaphore, "value", "getvalue");
	rb_define_attr(rb_cSemaphore, "name", true, false);
	return;
}

VALUE semaphore_initialize(VALUE rb_self, VALUE rb_name, VALUE rb_n)
{
	unsigned int n;
	char* name;
	sem_t* sem;

	n = NUM2INT(rb_n);
	name = StringValueCStr(rb_name);
	sem = sem_open(name, O_CREAT, S_IRUSR|S_IWUSR, n);
	if(sem == SEM_FAILED)
	{
		rb_sys_fail("sem_open");
	}
	rb_iv_set(rb_self, "sem_ptr", (VALUE)sem);
	rb_iv_set(rb_self, "@name", rb_name);

	return rb_self;
}

VALUE semaphore_post(VALUE rb_self)
{
	sem_t* sem;

	sem = (sem_t*)rb_iv_get(rb_self, "sem_ptr");
	if(sem_post(sem) != 0)
	{
		rb_sys_fail("sem_post");
	}
	return rb_self;
}

VALUE semaphore_wait(VALUE rb_self)
{
	sem_t* sem;
	int r;

	sem = (sem_t*)rb_iv_get(rb_self, "sem_ptr");
	r = (int)rb_thread_blocking_region((VALUE (*)(void *))sem_wait, sem, RUBY_UBF_IO, NULL);
	if(r != 0)
	{
		rb_sys_fail("sem_wait");
	}
	return rb_self;
}

VALUE semaphore_trywait(VALUE rb_self)
{
	sem_t* sem;
	int r;

	sem = (sem_t*)rb_iv_get(rb_self, "sem_ptr");
	r = (int)rb_thread_blocking_region((VALUE (*)(void *))sem_trywait, sem, RUBY_UBF_IO, NULL);
	if(sem_trywait(sem) != 0)
	{
		rb_sys_fail("sem_trywait");
	}
	return rb_self;
}

#ifdef HAVE_SEM_TIMEDWAIT
struct semaphore_sem_timedwait_wrap_data
{
	sem_t* sem;
	struct timespec* timeout;
};

int semaphore_sem_timedwait_wrap(struct semaphore_sem_timedwait_wrap_data* pdata)
{
	int r;

	r = sem_timedwait(pdata->sem, pdata->timeout);
	return r;
}

VALUE semaphore_timedwait(VALUE rb_self, VALUE rb_timeout)
{
	sem_t* sem;
	struct timespec timeout;
	struct semaphore_sem_timedwait_wrap_data data;
	int r;

	sem = (sem_t*)rb_iv_get(rb_self, "sem_ptr");
	timeout = rb_time_timespec(rb_timeout);
	data.sem = sem;
	data.timeout = &timeout;
	r = (int)rb_thread_blocking_region((VALUE (*)(void *))semaphore_sem_timedwait_wrap, &data, RUBY_UBF_IO, NULL);
	if(sem_timedwait(sem, &timeout) != 0)
	{
		rb_sys_fail("sem_timedwait");
	}
	return rb_self;
}
#endif

VALUE semaphore_close(VALUE rb_self)
{
	sem_t* sem;

	sem = (sem_t*)rb_iv_get(rb_self, "sem_ptr");
	if(sem_close(sem) != 0)
	{
		rb_sys_fail("sem_close");
	}
	return rb_self;
}

VALUE semaphore_unlink(VALUE rb_self)
{
	VALUE rb_name;
	char* name;

	rb_name = rb_iv_get(rb_self, "@name");
	name = StringValueCStr(rb_name);
	if(sem_unlink(name) != 0)
	{
		rb_sys_fail("sem_unlink");
	}
	return rb_self;
}

VALUE semaphore_getvalue(VALUE rb_self)
{
	sem_t* sem;
	int n;

	sem = (sem_t*)rb_iv_get(rb_self, "sem_ptr");
	if(sem_getvalue(sem, &n) != 0)
	{
		rb_sys_fail("sem_getvalue");
	}
	return INT2FIX(n);
}

