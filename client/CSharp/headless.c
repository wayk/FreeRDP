#include "devolutionsrdp.h"

#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>

BOOL csharp_create_shared_buffer(char* name, int size)
{
	BOOL result = FALSE;
	int desc = shm_open(name, O_RDWR | O_CREAT | O_EXCL, 0600);
	
	if(desc < 0)
		return NULL;
	
	if (ftruncate(desc, size) == 0)
		result = TRUE;
		//handle = mmap(0, size, PROT_READ | PROT_WRITE, MAP_SHARED, desc, 0);
	
	close(desc);
	
	return result;
}

void csharp_destroy_shared_buffer(char* name)
{
	//munmap(buffer, size);
	shm_unlink(name);
	
}
