import { Injectable, ApplicationRef, EnvironmentInjector, createComponent, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { ConfirmDialogComponent, ConfirmOptions } from '../components/shared/confirm-dialog/confirm-dialog';

@Injectable({
  providedIn: 'root'
})
export class ConfirmService {
  private appRef = inject(ApplicationRef);
  private injector = inject(EnvironmentInjector);

  confirm(options: ConfirmOptions | string): Observable<boolean> {
    const normalized: ConfirmOptions = typeof options === 'string' ? { message: options } : options;

    return new Observable<boolean>(subscriber => {
      const host = document.createElement('div');
      document.body.appendChild(host);

      const componentRef = createComponent(ConfirmDialogComponent, {
        environmentInjector: this.injector,
        hostElement: host,
      });
      componentRef.setInput('options', normalized);

      componentRef.instance.confirmed.subscribe((result: boolean) => {
        subscriber.next(result);
        subscriber.complete();
        componentRef.destroy();
        host.remove();
      });

      this.appRef.attachView(componentRef.hostView);
      componentRef.changeDetectorRef.detectChanges();
    });
  }
}