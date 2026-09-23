#ifndef TOOLBOX_IPV6_ADDRESS_FLAGS_H
#define TOOLBOX_IPV6_ADDRESS_FLAGS_H

#include <netinet/in.h>
#include <stdint.h>

/// Returns zero on success or an errno value if per-address flags could not be read.
int ToolboxIPv6AddressFlags(const char *interfaceName, const struct sockaddr_in6 *address, int32_t *flags);

#endif
