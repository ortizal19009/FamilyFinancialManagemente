import { HttpInterceptorFn } from '@angular/common/http';
import { NgZone, inject } from '@angular/core';
import { Observable } from 'rxjs';

export const zoneInterceptor: HttpInterceptorFn = (req, next) => {
  const ngZone = inject(NgZone);

  return new Observable((observer) => {
    const subscription = next(req).subscribe({
      next: (event) => ngZone.run(() => observer.next(event)),
      error: (error) => ngZone.run(() => observer.error(error)),
      complete: () => ngZone.run(() => observer.complete()),
    });

    return () => subscription.unsubscribe();
  });
};
