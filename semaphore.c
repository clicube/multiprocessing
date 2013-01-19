#include <stdbool.h>
#include <fcntl.h>           /* For O_* constants */
#include <sys/stat.h>        /* For mode constants */
#include <semaphore.h>
#include <ruby.h>

void Init_semaphore(void);
VALUE semaphore_open(int, VALUE*, VALUE);
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
	VALUE rb_cFile;
	VALUE rb_cStat;
	VALUE rb_mMultiProcessing;
	VALUE rb_cSemaphore;
	VALUE rb_cSem_t;

	rb_cFile = rb_const_get(rb_cObject, rb_intern("File"));
	rb_cStat = rb_const_get(rb_cFile, rb_intern("Stat"));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_ISUID")))
		rb_define_const(rb_cStat, "S_ISUID", INT2FIX(S_ISUID));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_ISGID")))
		rb_define_const(rb_cStat, "S_ISGID", INT2FIX(S_ISGID));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IVTX")))
		rb_define_const(rb_cStat, "S_ISVTX", INT2FIX(S_ISVTX));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IRWXU")))
		rb_define_const(rb_cStat, "S_IRWXU", INT2FIX(S_IRWXU));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IRUSR")))
		rb_define_const(rb_cStat, "S_IRUSR", INT2FIX(S_IRUSR));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IWUSR")))
		rb_define_const(rb_cStat, "S_IWUSR", INT2FIX(S_IWUSR));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IXUSR")))
		rb_define_const(rb_cStat, "S_IXUSR", INT2FIX(S_IXUSR));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IRWXG")))
		rb_define_const(rb_cStat, "S_IRWXG", INT2FIX(S_IRWXG));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IRGRP")))
		rb_define_const(rb_cStat, "S_IRGRP", INT2FIX(S_IRGRP));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IWGRP")))
		rb_define_const(rb_cStat, "S_IWGRP", INT2FIX(S_IWGRP));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IXGRP")))
		rb_define_const(rb_cStat, "S_IXGRP", INT2FIX(S_IXGRP));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IRWXO")))
		rb_define_const(rb_cStat, "S_IRWXO", INT2FIX(S_IRWXO));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IROTH")))
		rb_define_const(rb_cStat, "S_IROTH", INT2FIX(S_IROTH));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IWOTH")))
		rb_define_const(rb_cStat, "S_IWOTH", INT2FIX(S_IWOTH));
	if(!rb_const_defined_at(rb_cStat,rb_intern("S_IXOTH")))
		rb_define_const(rb_cStat, "S_IXOTH", INT2FIX(S_IXOTH));


	rb_mMultiProcessing = rb_define_module("MultiProcessing");
	rb_cSemaphore = rb_define_class_under(rb_mMultiProcessing, "Semaphore", rb_cObject);
	rb_cSem_t = rb_define_class_under(rb_cSemaphore, "Sem_t", rb_cObject);

	rb_define_method(rb_cSemaphore, "open", semaphore_open, -1);

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

struct sem_t_wrap
{
	sem_t* sem;
};

VALUE semaphore_wrap_sem(sem_t* sem)
{
	VALUE rb_mMultiProcessing, rb_cSemaphore, rb_cSem_t;
	VALUE rb_sem;
	struct sem_t_wrap* sem_wrap;

	rb_mMultiProcessing = rb_const_get(rb_cObject, rb_intern("MultiProcessing"));
	rb_cSemaphore = rb_const_get(rb_mMultiProcessing, rb_intern("Semaphore"));
	rb_cSem_t = rb_const_get(rb_cSemaphore, rb_intern("Sem_t"));

	rb_sem = Data_Make_Struct(rb_cSem_t, struct sem_t_wrap, 0, -1, sem_wrap);
	sem_wrap-> sem = sem;
	return rb_sem;
}

sem_t* semaphore_get_sem(VALUE rb_sem_wrap)
{
	struct sem_t_wrap* sem_wrap;
	Data_Get_Struct(rb_sem_wrap, struct sem_t_wrap, sem_wrap);
	return sem_wrap->sem;
}

VALUE semaphore_open(int argc, VALUE* argv, VALUE rb_self)
{
	VALUE rb_name, rb_oflag, rb_mode, rb_n;
	unsigned int n;
	char* name;
	int oflag;
	mode_t mode;
	sem_t* sem;
	VALUE rb_sem;

	rb_scan_args(argc, argv, "22", &rb_name, &rb_oflag, &rb_mode, &rb_n);

	name = StringValueCStr(rb_name);
	oflag = FIX2INT(rb_oflag);
	mode = NUM2MODET(rb_mode);
	n = NUM2INT(rb_n);
	if(argc >= 4)
	{
		sem = sem_open(name, oflag, mode, n);
	}
	else
	{
		sem = sem_open(name,oflag);
	}
	//sem = sem_open(name, O_CREAT, S_IRUSR|S_IWUSR, n);
	if(sem == SEM_FAILED)
	{
		rb_sys_fail("sem_open");
	}

	rb_sem = semaphore_wrap_sem(sem);
	rb_iv_set(rb_self, "sem_t", rb_sem);
	rb_iv_set(rb_self, "@name", rb_name);

	return rb_self;
}

VALUE semaphore_post(VALUE rb_self)
{
	VALUE rb_sem;
	sem_t* sem;

	rb_sem = rb_iv_get(rb_self, "sem_t");
	sem = semaphore_get_sem(rb_sem);
	if(sem_post(sem) != 0)
	{
		rb_sys_fail("sem_post");
	}
	return rb_self;
}

VALUE semaphore_wait(VALUE rb_self)
{
	VALUE rb_sem;
	sem_t* sem;
	int r;

	rb_sem = rb_iv_get(rb_self, "sem_t");
	sem = semaphore_get_sem(rb_sem);
	r = (int)rb_thread_blocking_region((VALUE (*)(void *))sem_wait, sem, RUBY_UBF_IO, NULL);
	if(r != 0)
	{
		rb_sys_fail("sem_wait");
	}
	return rb_self;
}

VALUE semaphore_trywait(VALUE rb_self)
{
	VALUE rb_sem;
	sem_t* sem;
	int r;

	rb_sem = rb_iv_get(rb_self, "sem_t");
	sem = semaphore_get_sem(rb_sem);
	r = (int)rb_thread_blocking_region((VALUE (*)(void *))sem_trywait, sem, RUBY_UBF_IO, NULL);
	if(r != 0)
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
	VALUE rb_sem;
	int r;

	r = sem_timedwait(pdata->sem, pdata->timeout);
	return r;
}

VALUE semaphore_timedwait(VALUE rb_self, VALUE rb_timeout)
{
	VALUE rb_sem;
	sem_t* sem;
	struct timespec timeout;
	struct semaphore_sem_timedwait_wrap_data data;
	int r;

	rb_sem = rb_iv_get(rb_self, "sem_t");
	sem = semaphore_get_sem(rb_sem);
	timeout = rb_time_timespec(rb_timeout);
	data.sem = sem;
	data.timeout = &timeout;
	r = (int)rb_thread_blocking_region((VALUE (*)(void *))semaphore_sem_timedwait_wrap, &data, RUBY_UBF_IO, NULL);
	if(r != 0)
	{
		rb_sys_fail("sem_timedwait");
	}
	return rb_self;
}
#endif

VALUE semaphore_close(VALUE rb_self)
{
	VALUE rb_sem;
	sem_t* sem;

	rb_sem = rb_iv_get(rb_self, "sem_t");
	sem = semaphore_get_sem(rb_sem);
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
	VALUE rb_sem;
	sem_t* sem;
	int n;

	rb_sem = rb_iv_get(rb_self, "sem_t");
	sem = semaphore_get_sem(rb_sem);
	if(sem_getvalue(sem, &n) != 0)
	{
		rb_sys_fail("sem_getvalue");
	}
	return INT2FIX(n);
}

