
// http://www.gnu.org/software/gettext/manual/gettext.html#libgettextpo
#include <gettext-po.h>
#include <assert.h>
#include "ruby.h"

extern "C" {

void xerror_handler(
	int severity,
	po_message_t message, const char *filename, size_t lineno,
	size_t column, int multiline_p, const char *message_text)
{
	printf("filename = %s, lineno = %lu, column = %lu\n", filename, lineno, column);
	assert(0);
}

void xerror2_handler(
	int severity,
	po_message_t message1, const char *filename1, size_t lineno1,
	size_t column1, int multiline_p1, const char *message_text1,
	po_message_t message2, const char *filename2, size_t lineno2,
	size_t column2, int multiline_p2, const char *message_text2)
{
	assert(0);
}

VALUE wrap_po_message(po_message_t message)
{
	VALUE res = rb_hash_new();

	// === msgid ===
	rb_hash_aset(res, rb_str_new2("msgid"), rb_str_new2(po_message_msgid(message)));
	// === msgid_plural ===
	if (po_message_msgid_plural(message))
		rb_hash_aset(res, rb_str_new2("msgid_plural"), rb_str_new2(po_message_msgid_plural(message)));

	// TODO: Make loading of previous translation optional (for optimization)
	// === msgid_previous ===
	if (po_message_prev_msgid(message))
		rb_hash_aset(res, rb_str_new2("msgid_previous"), rb_str_new2(po_message_prev_msgid(message)));
	// === msgid_plural_previous ===
	if (po_message_prev_msgid_plural(message))
		rb_hash_aset(res, rb_str_new2("msgid_plural_previous"), rb_str_new2(po_message_prev_msgid_plural(message)));

	// === msgstr ===
	VALUE msgstr_array = rb_ary_new();
	if (po_message_msgstr_plural(message, 0)) // message has plural forms
	{
		for (int i = 0; po_message_msgstr_plural(message, i); i ++)
			rb_ary_push(msgstr_array, rb_str_new2(po_message_msgstr_plural(message, i)));
	}
	else // single msgstr
	{
		rb_ary_push(msgstr_array, rb_str_new2(po_message_msgstr(message)));
	}

	rb_hash_aset(res, rb_str_new2("msgstr"), msgstr_array);

	// === obsolete ===
	rb_hash_aset(res, rb_str_new2("obsolete"), po_message_is_obsolete(message) ? Qtrue : Qfalse);
	// === fuzzy ===
	rb_hash_aset(res, rb_str_new2("fuzzy"), po_message_is_fuzzy(message) ? Qtrue : Qfalse);

	// TODO: read more fields
	// See /usr/include/gettext-po.h for appropriate functions

	return res;
}

VALUE wrap_read_po_file(VALUE self, VALUE filename)
{
	struct po_xerror_handler xerror_handlers;
	xerror_handlers.xerror = xerror_handler;
	xerror_handlers.xerror2 = xerror2_handler;

	po_file_t file = po_file_read(StringValuePtr(filename), &xerror_handlers);
	if (file == NULL)
	{
		return Qnil;
	}

	const char * const *domains = po_file_domains(file);
	assert(strcmp(domains[0], "messages") == 0);
	assert(domains[1] == NULL);

	// create Ruby array
	VALUE res = rb_ary_new();

	// main cycle
	po_message_iterator_t iterator = po_message_iterator(file, "messages");
	po_message_t message; // in fact, this is a pointer
	while (message = po_next_message(iterator))
	{
		rb_ary_push(res, wrap_po_message(message));
	}

	po_file_free(file); // free memory
	return res;
}

/* Function called at module loading */
void Init_poreader()
{
	VALUE PoReader = rb_define_module("PoReader");
	rb_define_singleton_method(PoReader, "read_po_file", RUBY_METHOD_FUNC(wrap_read_po_file), 1);
}

}

