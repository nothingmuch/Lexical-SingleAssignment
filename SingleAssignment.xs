#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "ptable.h"


#include "hook_op_check.h"


#define MY_CXT_KEY "Lexical::SingleAssignment::_guts" XS_VERSION

typedef struct {
	PTABLE_t *padop_table;
	int padop_table_refcount;
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

/* post hook for aassign that marks SVs as readonly */
STATIC OP *
pp_aassign_readonly (pTHX) {
	dSP;
	SV **lvalues;
	SV **first = &PL_stack_base[TOPMARK + 1];
	int items = 1 + ( SP - first );

	Newx(lvalues, items, SV *);
	save_freepv(lvalues);

	Copy(first, lvalues, items, SV *);

	OP *ret = PL_ppaddr[OP_AASSIGN](aTHXR);

	while ( items ) {
		SV *sv = lvalues[--items];

		if ( SvTYPE(sv) == SVt_PVAV ) {
			AV *av = (AV *)sv;
			SV **array = AvARRAY(av);
			int i;

			for ( i = 0; i < AvMAX(av); i++ ) {
				SvREADONLY_on(array[i]);
			}
		} else if ( SvTYPE(sv) == SVt_PVHV ) {
			HV *hv = (HV *)sv;
			HE *he;
			SV *val;

			hv_iterinit(hv);

			while ( he = hv_iternext(hv) ) {
				SvREADONLY_on(hv_iterval(hv, he));
			}
		}

		SvREADONLY_on(sv);
	}

	return ret;
}



/* modify sassign ops */
STATIC OP *
lsa_ck_sassign(pTHX_ OP *o, void *ud) {
	OP *rvalue = cBINOPo->op_first;

	if ( rvalue ) {
		OP *lvalue = rvalue->op_sibling;

		if ( lvalue ) {
			switch ( lvalue->op_type ) {
				case OP_PADSV:
				case OP_PADHV:
				case OP_PADAV:	
					if ( lvalue->op_private & OPpLVAL_INTRO ) {
						if ( o->op_ppaddr == PL_ppaddr[OP_SASSIGN] ) {
							o->op_ppaddr = pp_sassign_readonly;

							assert(MY_CXT.padop_table != NULL);
							PTABLE_store(MY_CXT.padop_table, lvalue, NULL);
						} else {
							warn("Not overriding assignment op (already augmented)");
						}
					} else if ( PTABLE_fetch(MY_CXT.padop_table, lvalue) ) {
						croak("Assignment to lexical allowed only in declaration");
					}
			}
		}
	}

	return o;
}

STATIC OP *
lsa_ck_aassign(pTHX_ OP *o, void *ud) {
	LISTOP *lvalues = (LISTOP *)cBINOPo->op_first->op_sibling;
	OP *lvalue;
	bool augment_readonly = FALSE;

	for ( lvalue = lvalues->op_first->op_sibling; lvalue; lvalue = lvalue->op_sibling ) {
		switch ( lvalue->op_type ) {
			case OP_PADSV:
			case OP_PADHV:
			case OP_PADAV:
				if ( lvalue->op_private & OPpLVAL_INTRO ) {
					augment_readonly = TRUE;
					assert(MY_CXT.padop_table != NULL);
					PTABLE_store(MY_CXT.padop_table, lvalue, NULL);
				} else if ( PTABLE_fetch(MY_CXT.padop_table, lvalue) ) {
					croak("Assignment to lexical allowed only in declaration");
				}
		}
	}

	if ( augment_readonly ) {
		if ( o->op_ppaddr == PL_ppaddr[OP_AASSIGN] ) {
			o->op_ppaddr = pp_aassign_readonly;
		} else {
			warn("Not overriding assignment op (already augmented)");
		}
	}

	return o;
}

STATIC void
delayed_ck_padany(pTHX_ OP *o) {
	assert(MY_CXT.padop_table != NULL);

	switch ( o->op_type ) {
		case OP_PADSV:
		case OP_PADHV:
		case OP_PADAV:
			if ( o->op_private & OPpLVAL_INTRO ) {
				if ( PTABLE_fetch(MY_CXT.padop_table, o) ) {
					/* FIXME the table contains PL_curcup at check time, use it for a better error message */
					if ( PL_in_eval && !(PL_in_eval & EVAL_KEEPERR) ) {
						croak("Declaration of lexical without assignment");
					}
				}

				break;
			}

			/* fall through */
		default:
			PTABLE_store(MY_CXT.padop_table, o, NULL);
	}
}

STATIC OP *
lsa_ck_padany(pTHX_ OP *o, void *ud) {
	assert(MY_CXT.padop_table != NULL);

	PTABLE_store(MY_CXT.padop_table, o, &PL_curcop);
	SAVEDESTRUCTOR_X(delayed_ck_padany, (void *)o);
	return o;
}

MODULE = Lexical::SingleAssignment	PACKAGE = Lexical::SingleAssignment

PROTOTYPES: ENABLE

BOOT:
{
	MY_CXT.padop_table = NULL;
	MY_CXT.padop_table_refcount = 0;
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
setup_aassign (class)
        SV *class;
    CODE:
        RETVAL = hook_op_check (OP_AASSIGN, lsa_ck_aassign, NULL);
    OUTPUT:
        RETVAL

void
teardown_aassign (class, hook)
        hook_op_check_id hook
    CODE:
        (void)hook_op_check_remove (OP_AASSIGN, hook);




hook_op_check_id
setup_padany (class)
        SV *class;
    CODE:
		if ( !MY_CXT.padop_table ) {
			assert( MY_CXT.ptable_refcount == 0 );
			MY_CXT.padop_table = PTABLE_new();
		}

		MY_CXT.padop_table_refcount++;
		assert( MY_CXT.padop_table_refcount > 0 );

        RETVAL = hook_op_check (OP_PADANY, lsa_ck_padany, NULL);
    OUTPUT:
        RETVAL

void
teardown_padany (class, hook)
        hook_op_check_id hook
    CODE:
		assert( MY_CXT.padop_table != NULL );
		assert( MY_CXT.padop_table_refcount > 0 );

		if ( MY_CXT.padop_table_refcount-- == 0 ) {
			PTABLE_free(MY_CXT.padop_table);
			MY_CXT.padop_table = NULL;
		}

        (void)hook_op_check_remove (OP_PADANY, hook);

