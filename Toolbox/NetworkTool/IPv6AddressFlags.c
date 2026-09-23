#include "IPv6AddressFlags.h"

#include <errno.h>
#include <netinet6/in6_var.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

int ToolboxIPv6AddressFlags(const char *interfaceName, const struct sockaddr_in6 *address, int32_t *flags) {
    if (interfaceName == NULL || address == NULL || flags == NULL) {
        return EINVAL;
    }

    struct in6_ifreq request = {0};
    if (strlcpy(request.ifr_name, interfaceName, sizeof(request.ifr_name)) >= sizeof(request.ifr_name)) {
        return ENAMETOOLONG;
    }
    request.ifr_ifru.ifru_addr = *address;

    int descriptor = socket(AF_INET6, SOCK_DGRAM, 0);
    if (descriptor < 0) {
        return errno;
    }
    int result = ioctl(descriptor, SIOCGIFAFLAG_IN6, &request);
    int error = result < 0 ? errno : 0;
    close(descriptor);
    if (error == 0) {
        *flags = request.ifr_ifru.ifru_flags6;
    }
    return error;
}
