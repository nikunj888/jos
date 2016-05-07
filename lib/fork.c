// implement fork from user space

#include <inc/string.h>
#include <inc/lib.h>

// PTE_COW marks copy-on-write page table entries.
// It is one of the bits explicitly allocated to user processes (PTE_AVAIL).
#define PTE_COW		0x800

//
// Custom page fault handler - if faulting page is copy-on-write,
// map in our own private writable copy.
//
static void
pgfault(struct UTrapframe *utf)
{
	void *addr = (void *) utf->utf_fault_va;
	uint32_t err = utf->utf_err;
	int r;

	// Check that the faulting access was (1) a write, and (2) to a
	// copy-on-write page.  If not, panic.
	// Hint:
	//   Use the read-only page table mappings at uvpt
	//   (see <inc/memlayout.h>).

	// LAB 4: Your code here.
	if (!((err & FEC_WR) && (uvpt[PGNUM(addr)] & PTE_COW)))
		panic("pgfault: not write fault or page not COW\n");

	// Allocate a new page, map it at a temporary location (PFTEMP),
	// copy the data from the old page to the new page, then move the new
	// page to the old page's address.
	// Hint:
	//   You should make three system calls.

	// LAB 4: Your code here.
	if ((r = sys_page_alloc(0, PFTEMP, PTE_P | PTE_U | PTE_W)) < 0)	// allocate a new page at temp location
		panic("pgfault: sys_page_alloc returned %e\n", r);
		
	memmove(PFTEMP, ROUNDDOWN(addr, PGSIZE), PGSIZE);				// copy the date from old page to new page
	
	if ((r = sys_page_map(0, PFTEMP, 0, ROUNDDOWN(addr, PGSIZE), PTE_P | PTE_U | PTE_W)) < 0)	// map the new page at the old page's address
		panic("pgfault: sys_page_map returned %e\n", r);
	
	if ((r = sys_page_unmap(0, PFTEMP)) < 0)						// unmap the temporary page
		panic("pgfault: sys_page_unmap returned %e\n", r);
}

//
// Map our virtual page pn (address pn*PGSIZE) into the target envid
// at the same virtual address.  If the page is writable or copy-on-write,
// the new mapping must be created copy-on-write, and then our mapping must be
// marked copy-on-write as well.  (Exercise: Why do we need to mark ours
// copy-on-write again if it was already copy-on-write at the beginning of
// this function?)
//
// Returns: 0 on success, < 0 on error.
// It is also OK to panic on error.
//
static int
duppage(envid_t envid, unsigned pn)
{
	int r;

	// LAB 4: Your code here.
	void* va = (void*) (pn << PGSHIFT);			// find the va corresponding to pn
	
	int perm = PTE_P | PTE_U;			// default permissions
	
	if (uvpt[pn] & PTE_SHARE)				// page is marked as shared page
		perm = uvpt[pn] & PTE_SYSCALL;		// copy as is without changing permissions
	else if (uvpt[pn] & (PTE_W | PTE_COW))	// if page being copied has W or COW permission, make it COW only
		perm |= PTE_COW;
		
	if ((r = sys_page_map(0, va, envid, va, perm)) < 0)		// copy mappings from curenv to envid's environment
		return r;
	
	if ((r = sys_page_map(0, va, 0, va, perm)) < 0)			// remap the current env mappings with new permissions
		return r;

	return 0;
}

//
// User-level fork with copy-on-write.
// Set up our page fault handler appropriately.
// Create a child.
// Copy our address space and page fault handler setup to the child.
// Then mark the child as runnable and return.
//
// Returns: child's envid to the parent, 0 to the child, < 0 on error.
// It is also OK to panic on error.
//
// Hint:
//   Use uvpd, uvpt, and duppage.
//   Remember to fix "thisenv" in the child process.
//   Neither user exception stack should ever be marked copy-on-write,
//   so you must allocate a new page for the child's user exception stack.
//
envid_t
fork(void)
{
	// LAB 4: Your code here.
	set_pgfault_handler(pgfault);
	envid_t envid;
	int r;
	
	if ((envid = sys_exofork()) < 0)	// envid is id of child process, not parent
		panic("fork: sys_exofork returned %e\n", envid);
	
	if (envid == 0)		// child process should set thisenv and return 0
	{
		thisenv = &envs[ENVX(sys_getenvid())];
		return 0;		// fork should return 0 to child
	}
	
	// Only parent should run following code
	
	uint32_t pn = 0;
	for (pn = 0; pn < PGNUM(UTOP); pn++)	// for all pages till UTOP
	{
		if ((uvpd[PDX(pn << PTXSHIFT)] & PTE_P) == 0)		// check PDE permissions
			continue;
		if ((uvpt[pn] & (PTE_P | PTE_U)) == 0)			// check PTE permissions
			continue;
		
		if (pn != PGNUM(UXSTACKTOP - PGSIZE))			// if not Exception stack
			if ((r = duppage(envid, pn)) < 0)			// duplicate the page mappings
				panic("fork: duppage returned %e\n", r);							
	}
	
	if ((r = sys_page_alloc(envid, (void *) (UXSTACKTOP - PGSIZE), PTE_P | PTE_U | PTE_W)) < 0)	// allocate a new page for Exception stack for child
		panic("fork: sys_page_alloc returned %e\n", r);
	
	if ((r = sys_env_set_pgfault_upcall(envid, thisenv->env_pgfault_upcall)) < 0)	// register pgfault upcall for child to be same as parent's
		panic("fork: sys_env_set_pgfault_upcall returned %e\n", r);
		
	if ((r = sys_env_set_status(envid, ENV_RUNNABLE)) < 0)		// set status of child to runnable
		panic("fork: sys_env_set_status returned %e\n", r);
		
	return envid;			// fork returns id of child to parent
}

// Challenge!
int
sfork(void)
{
	panic("sfork not implemented");
	return -E_INVAL;
}
