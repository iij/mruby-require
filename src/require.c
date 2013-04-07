#include "mruby.h"
#include "mruby/compile.h"
#include "mruby/dump.h"
#include "mruby/string.h"
#include "mruby/proc.h"

#include "opcode.h"
#include "error.h"

#define E_LOAD_ERROR (mrb_class_obj_get(mrb, "LoadError"))

mrb_value
mrb_yield_internal(mrb_state *mrb, mrb_value b, int argc, mrb_value *argv, mrb_value self, struct RClass *c);

static void
replace_stop_with_return(mrb_state *mrb, mrb_irep *irep)
{
  if (irep->iseq[irep->ilen - 1] == MKOP_A(OP_STOP, 0)) {
    irep->iseq = mrb_realloc(mrb, irep->iseq, (irep->ilen + 1) * sizeof(mrb_code));
    irep->iseq[irep->ilen - 1] = MKOP_A(OP_LOADNIL, 0);
    irep->iseq[irep->ilen] = MKOP_AB(OP_RETURN, 0, OP_R_NORMAL);
    irep->ilen++;
  }
}

static int
compile_rb2mrb(mrb_state *mrb0, const char *code, int code_len, const char *path, FILE* tmpfp)
{
  mrb_state *mrb = mrb_open();
  mrbc_context *c;
  mrb_value irep_size;
  int ret = -1;
  int irep_len = mrb->irep_len;
  int debuginfo = 1;

  c = mrbc_context_new(mrb);
  c->no_exec = 1;
  if (path != NULL) {
    mrbc_filename(mrb, c, path);
  }

  irep_size = mrb_load_nstring_cxt(mrb, code, code_len, c);

  mrb->irep     += mrb_fixnum(irep_size);
  mrb->irep_len -= irep_len;

  ret = mrb_dump_irep_binary(mrb, 0, debuginfo, tmpfp);

  mrb->irep     -= mrb_fixnum(irep_size);
  mrb->irep_len += irep_len;
  mrbc_context_free(mrb, c);
  mrb_close(mrb);

  return ret;
}

static void
eval_load_irep(mrb_state *mrb, int n)
{
  int ai;
  struct RProc *proc;
  mrb_irep *irep = mrb->irep[n];

  replace_stop_with_return(mrb, irep);
  proc = mrb_proc_new(mrb, irep);
  proc->target_class = mrb->object_class;

  ai = mrb_gc_arena_save(mrb);
  mrb_yield_internal(mrb, mrb_obj_value(proc), 0, NULL, mrb_top_self(mrb), mrb->object_class);
  mrb_gc_arena_restore(mrb, ai);
}

static mrb_value
mrb_require_load_rb_str(mrb_state *mrb, mrb_value self)
{
  char *path_ptr = NULL;
  FILE *tmpfp = NULL;
  int ret;
  mrb_value code, path = mrb_nil_value();

  mrb_get_args(mrb, "S|S", &code, &path);
  if (!mrb_string_p(path)) {
    path = mrb_str_new_cstr(mrb, "-");
  }
  path_ptr = mrb_str_to_cstr(mrb, path);

  tmpfp = tmpfile();
  if (tmpfp == NULL) {
    mrb_sys_fail(mrb, "can't create tmpfile() at mrb_require_load_rb_str");
  }

  ret = compile_rb2mrb(mrb, RSTRING_PTR(code), RSTRING_LEN(code), path_ptr, tmpfp);
  if (ret != MRB_DUMP_OK) {
    fclose(tmpfp);
    mrb_raisef(mrb, E_LOAD_ERROR, "can't load file -- %S", path);
    return mrb_nil_value();
  }

  rewind(tmpfp);
  ret = mrb_read_irep_file(mrb, tmpfp);
  fclose(tmpfp);

  if (ret >= 0) {
    eval_load_irep(mrb, ret);
  } else if (mrb->exc) {
    // fail to load
    longjmp(*(jmp_buf*)mrb->jmp, 1);
  } else {
    mrb_raisef(mrb, E_LOAD_ERROR, "can't load file -- %S", path);
    return mrb_nil_value();
  }

  return mrb_true_value();
}

static mrb_value
mrb_require_load_mrb_file(mrb_state *mrb, mrb_value self)
{
  char *path_ptr = NULL;
  FILE *fp = NULL;
  int ret;
  mrb_value path;

  mrb_get_args(mrb, "S", &path);
  path_ptr = mrb_str_to_cstr(mrb, path);

  fp = fopen(path_ptr, "rb");
  if (fp == NULL) {
    mrb_raisef(mrb, E_LOAD_ERROR, "can't open file -- %S", path);
  }

  ret = mrb_read_irep_file(mrb, fp);

  if (ret >= 0) {
    eval_load_irep(mrb, ret);
  } else if (mrb->exc) {
    // fail to load
    longjmp(*(jmp_buf*)mrb->jmp, 1);
  } else {
    mrb_raisef(mrb, E_LOAD_ERROR, "can't load file -- %S", path);
    return mrb_nil_value();
  }

  return mrb_true_value();
}

void
mrb_mruby_require_gem_init(mrb_state *mrb)
{
  struct RClass *krn;
  krn = mrb->kernel_module;

  mrb_define_method(mrb, krn, "_load_rb_str",   mrb_require_load_rb_str,   ARGS_ANY());
  mrb_define_method(mrb, krn, "_load_mrb_file", mrb_require_load_mrb_file, ARGS_REQ(1));
}

void
mrb_mruby_require_gem_final(mrb_state *mrb)
{
}
