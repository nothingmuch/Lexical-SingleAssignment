#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "ptable.h"


#include "hook_op_check.h"


#define MY_CXT_KEY "Lexical::SingleAssignment::_guts" XS_VERSION

typedef struct {
	PTABLE_t *padsv_table;
	int padsv_table_refcount;
} my_cxt_t;

START_MY_CXT



/* post hook for sassign that marks SVs as readonly */
STATIC OP *
pp_sassign_readonly (pTHX) {
	dSP;

	OP *ret = PL_ppaddr[OP_SASSIGN](aTHXR);

	SPAGAIN;

	assert(SvPADMY(TOPs));

	SvREADONLY_on(TOPs);

	return ret;
}



/* modify sassign ops */
STATIC OP *
lsa_ck_sassign(pTHX_ OP *o, void *ud) {
	OP *rvalue = cBINOPo->op_first;

	if ( rvalue ) {
		OP *lvalue = rvalue->op_sibling;

		if ( lvalue && lvalue->op_type == OP_PADSV ) {
			if ( lvalue->op_private & OPpLVAL_INTRO ) {
				if ( o->op_ppaddr == PL_ppaddr[OP_SASSIGN] ) {
					o->op_ppaddr = pp_sassign_readonly;

					assert(MY_CXT.padsv_table != NULL);
					PTABLE_store(MY_CXT.padsv_table, lvalue, NULL);
				} else {
					warn("Not overriding assignment op (already augmented)");
				}
			} else {
				croak("Assignment to lexical allowed only in declaration");
			}
		}
	}

	return o;
}

STATIC void
delayed_ck_padany(pTHX_ OP *o) {
	assert(MY_CXT.padsv_table != NULL);

	if ( o->op_type == OP_PADSV && o->op_private & OPpLVAL_INTRO ) {
		if ( PTABLE_fetch(MY_CXT.padsv_table, o) ) { /* FIXME this is PL_curcup at check time, use it for a better error message */
			PTABLE_store(MY_CXT.padsv_table, o, NULL);
			sv_setpvs(get_sv("Lexical::SingleAssignment::error", 1), "Declaration of lexical without assignment\n");
		}
	} else {
		PTABLE_store(MY_CXT.padsv_table, o, NULL);
	}
}

STATIC OP *
lsa_ck_padany(pTHX_ OP *o, void *ud) {
	assert(MY_CXT.padsv_table != NULL);

	PTABLE_store(MY_CXT.padsv_table, o, &PL_curcop);
	SAVEDESTRUCTOR_X(delayed_ck_padany, (void *)o);
	return o;
}

MODULE = Lexical::SingleAssignment	PACKAGE = Lexical::SingleAssignment

PROTOTYPES: ENABLE

BOOT:
{
	MY_CXT.padsv_table = NULL;
	MY_CXT.padsv_table_refcount = 0;
}

hook_op_check_id
setup_sassign (class)
        SV *class;
    CODE:
        RETVAL = hook_op_check (OP_SASSIGN, lsa_ck_sassign, NULL);
    OUTPUT:
        RETVAL

void
teardown_sassign (class, hook)
        hook_op_check_id hook
    CODE:
        (void)hook_op_check_remove (OP_SASSIGN, hook);




hook_op_check_id
setup_padany (class)
        SV *class;
    CODE:
		if ( !MY_CXT.padsv_table ) {
			assert( MY_CXT.ptable_refcount == 0 );
			MY_CXT.padsv_table = PTABLE_new();
		}

		MY_CXT.padsv_table_refcount++;
		assert( MY_CXT.padsv_table_refcount > 0 );

        RETVAL = hook_op_check (OP_PADANY, lsa_ck_padany, NULL);
    OUTPUT:
        RETVAL

void
teardown_padany (class, hook)
        hook_op_check_id hook
    CODE:
		assert( MY_CXT.padsv_table != NULL );
		assert( MY_CXT.padsv_table_refcount > 0 );

		if ( MY_CXT.padsv_table_refcount-- == 0 ) {
			PTABLE_free(MY_CXT.padsv_table);
			MY_CXT.padsv_table = NULL;
		}

        (void)hook_op_check_remove (OP_PADANY, hook);

