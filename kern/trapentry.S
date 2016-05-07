/* See COPYRIGHT for copyright information. */

#include <inc/mmu.h>
#include <inc/memlayout.h>
#include <inc/trap.h>

#include <kern/picirq.h>


###################################################################
# exceptions/interrupts
###################################################################

/* TRAPHANDLER defines a globally-visible function for handling a trap.
 * It pushes a trap number onto the stack, then jumps to _alltraps.
 * Use TRAPHANDLER for traps where the CPU automatically pushes an error code.
 *
 * You shouldn't call a TRAPHANDLER function from C, but you may
 * need to _declare_ one in C (for instance, to get a function pointer
 * during IDT setup).  You can declare the function with
 *   void NAME();
 * where NAME is the argument passed to TRAPHANDLER.
 */
#define TRAPHANDLER(name, num)						\
	.globl name;		/* define global symbol for 'name' */	\
	.type name, @function;	/* symbol type is function */		\
	.align 2;		/* align function definition */		\
	name:			/* function starts here */		\
	pushl $(num);							\
	jmp _alltraps

/* Use TRAPHANDLER_NOEC for traps where the CPU doesn't push an error code.
 * It pushes a 0 in place of the error code, so the trap frame has the same
 * format in either case.
 */
#define TRAPHANDLER_NOEC(name, num)					\
	.globl name;							\
	.type name, @function;						\
	.align 2;							\
	name:								\
	pushl $0;							\
	pushl $(num);							\
	jmp _alltraps

.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
// Check in 80386 manual whether EC or NOEC
TRAPHANDLER_NOEC(divide_fault, T_DIVIDE);
TRAPHANDLER_NOEC(debug_exception, T_DEBUG);
TRAPHANDLER_NOEC(nmi_interrupt, T_NMI);
TRAPHANDLER_NOEC(breakpoint_trap, T_BRKPT);
TRAPHANDLER_NOEC(overflow_trap, T_OFLOW);
TRAPHANDLER_NOEC(bound_fault, T_BOUND);
TRAPHANDLER_NOEC(invalid_op_fault, T_ILLOP);
TRAPHANDLER_NOEC(device_unavailable_fault, T_DEVICE);
TRAPHANDLER(doublefault_abort, T_DBLFLT);
TRAPHANDLER_NOEC(coprocessor_segoverrun, T_COPROC);
TRAPHANDLER(invalid_tss_fault, T_TSS);
TRAPHANDLER(seg_not_present_fault, T_SEGNP);
TRAPHANDLER(stack_fault, T_STACK);
TRAPHANDLER(general_protection_fault, T_GPFLT);
TRAPHANDLER(page_fault, T_PGFLT);
TRAPHANDLER_NOEC(reserved_trap, T_RES);
TRAPHANDLER_NOEC(fpu_fault, T_FPERR);
TRAPHANDLER(aligment_check_fault, T_ALIGN);
TRAPHANDLER_NOEC(machine_check_abort, T_MCHK);
TRAPHANDLER_NOEC(simd_fault, T_SIMDERR);

// Handler for syscalls
TRAPHANDLER_NOEC(syscall_interrupt, T_SYSCALL);

// Handlers for HW interrupts
TRAPHANDLER_NOEC(timer_irq, IRQ_OFFSET + IRQ_TIMER);
TRAPHANDLER_NOEC(kbd_irq, IRQ_OFFSET + IRQ_KBD);
TRAPHANDLER_NOEC(serial_irq, IRQ_OFFSET + IRQ_SERIAL);
TRAPHANDLER_NOEC(spurious_irq, IRQ_OFFSET + IRQ_SPURIOUS);
TRAPHANDLER_NOEC(ide_irq, IRQ_OFFSET + IRQ_IDE);
TRAPHANDLER_NOEC(error_irq, IRQ_OFFSET + IRQ_ERROR);


/*
 * Lab 3: Your code here for _alltraps
 */
.globl _alltraps
_alltraps:
	pushl %ds			// refer to trapframe struct in xv6 book (P40) and struct Trapframe in inc/trap.h
	pushl %es
	pushal				// Push major regs

	movw $GD_KD, %ax
	movw %ax, %ds		// WHY??
	movw %ax, %es

	pushl %esp

	call trap			// will it return?

	/*addl $0x04, %esp*/
	/* 	popal*/
	/* 	popl %es*/
	/* 	popl %ds*/
	/* 	# ignore the trap number and 0 padding*/
	/* 	addl $0x08, %esp*/
	/* 	iret*/
	
// Interrupt Vector Table
.data								// write in data segment
.globl ivt							// tell assembler that ivt is accessible outside this file.
ivt:
	// long because address
	.long divide_fault				#0
	.long debug_exception			#1
	.long nmi_interrupt				#2
	.long breakpoint_trap			#3
	.long overflow_trap				#4
	.long bound_fault				#5
	.long invalid_op_fault			#6
	.long device_unavailable_fault	#7
	.long doublefault_abort			#8
	.long coprocessor_segoverrun	#9
	.long invalid_tss_fault			#10
	.long seg_not_present_fault		#11
	.long stack_fault				#12
	.long general_protection_fault	#13
	.long page_fault				#14
	.long reserved_trap				#15
	.long fpu_fault					#16
	.long aligment_check_fault		#17
	.long machine_check_abort		#18
	.long simd_fault				#19
	
	// generate entries from 20 to 31
	.rept IRQ_OFFSET-20
	.long 0
	.endr
	
	// hardware interrupts
	.long timer_irq					#32	IRQ_OFFSET + 0
	.long kbd_irq					#33 IRQ_OFFSET + 1
	.long 0							#34
	.long 0							#35 
	.long serial_irq				#36 IRQ_OFFSET + 4
	.long 0							#37
	.long 0							#38 
	.long spurious_irq				#39 IRQ_OFFSET + 7
	.long 0							#40
	.long 0							#41 
	.long 0							#42
	.long 0							#43 
	.long 0							#44
	.long 0							#45 
	.long ide_irq					#46 IRQ_OFFSET + 14
	.long 0							#47 
	.long syscall_interrupt			#48 = 0x30
	.long 0							#49 
	.long 0							#50 
	.long error_irq					#51
	
	
