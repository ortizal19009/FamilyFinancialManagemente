import { HttpInterceptorFn, HttpResponse } from '@angular/common/http';
import { tap } from 'rxjs/operators';

export const timingInterceptor: HttpInterceptorFn = (req, next) => {
  const start = performance.now();

  return next(req).pipe(
    tap({
      next: (event) => {
        if (event instanceof HttpResponse) {
          console.log(
            `${req.method} ${req.urlWithParams} -> ${(performance.now() - start).toFixed(2)} ms`
          );
        }
      },
      error: () => {
        console.log(
          `${req.method} ${req.urlWithParams} -> ${(performance.now() - start).toFixed(2)} ms (error)`
        );
      }
    })
  );
};
