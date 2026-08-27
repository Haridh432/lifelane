#ifndef FIREBASE_H
#define FIREBASE_H

#include "gnss.h"

namespace Firebase
{
    bool uploadLocation(
        const LocationData &location
    );
}

#endif