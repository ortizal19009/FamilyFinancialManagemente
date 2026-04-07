import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-planning',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './planning.html',
  styleUrl: './planning.scss'
})
export class PlanningComponent implements OnInit {
  private apiService = inject(ApiService);

  planningData: any[] = [];
  categories: any[] = [];
  editingPlanId: number | null = null;
  
  selectedMonth: number = new Date().getMonth() + 1;
  selectedYear: number = new Date().getFullYear();
  
  months = [
    { value: 1, name: 'Enero' }, { value: 2, name: 'Febrero' }, { value: 3, name: 'Marzo' },
    { value: 4, name: 'Abril' }, { value: 5, name: 'Mayo' }, { value: 6, name: 'Junio' },
    { value: 7, name: 'Julio' }, { value: 8, name: 'Agosto' }, { value: 9, name: 'Septiembre' },
    { value: 10, name: 'Octubre' }, { value: 11, name: 'Noviembre' }, { value: 12, name: 'Diciembre' }
  ];

  newPlan = {
    category_id: null,
    planned_amount: 0,
    month: this.selectedMonth,
    year: this.selectedYear
  };

  loading = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadCategories();
    this.loadPlanning();
  }

  loadCategories() {
    this.apiService.getCategories().subscribe(data => this.categories = data);
  }

  loadPlanning() {
    this.apiService.getPlanning(this.selectedMonth, this.selectedYear).subscribe(data => {
      this.planningData = data;
    });
  }

  onFilterChange() {
    this.loadPlanning();
    this.newPlan.month = this.selectedMonth;
    this.newPlan.year = this.selectedYear;
  }

  onSavePlan() {
    this.loading = true;
    const request$ = this.editingPlanId === null
      ? this.apiService.savePlanning(this.newPlan)
      : this.apiService.updatePlanning(this.editingPlanId, this.newPlan);

    request$.subscribe({
      next: () => {
        this.successMsg = this.editingPlanId === null
          ? 'Presupuesto guardado correctamente'
          : 'Presupuesto actualizado correctamente';
        this.loadPlanning();
        this.resetPlanForm();
        this.loading = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'Error al guardar el presupuesto';
        this.loading = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEditPlan(plan: any) {
    this.editingPlanId = plan.id;
    this.newPlan = {
      category_id: plan.category_id ?? null,
      planned_amount: plan.planned_amount ?? 0,
      month: plan.month ?? this.selectedMonth,
      year: plan.year ?? this.selectedYear
    };
  }

  onDeletePlan(plan: any) {
    const confirmed = window.confirm(`¿Deseas eliminar el presupuesto de "${plan.category_name}"?`);
    if (!confirmed) {
      return;
    }

    this.apiService.deletePlanning(plan.id).subscribe({
      next: () => {
        this.successMsg = 'Presupuesto eliminado correctamente';
        if (this.editingPlanId === plan.id) {
          this.resetPlanForm();
        }
        this.loadPlanning();
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'Error al eliminar el presupuesto';
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onCancelEdit() {
    this.resetPlanForm();
  }

  private resetPlanForm() {
    this.editingPlanId = null;
    this.newPlan = {
      category_id: null,
      planned_amount: 0,
      month: this.selectedMonth,
      year: this.selectedYear
    };
  }

  getProgressBarClass(planned: number, actual: number): string {
    const percentage = (actual / planned) * 100;
    if (percentage > 100) return 'bg-danger';
    if (percentage > 80) return 'bg-warning';
    return 'bg-success';
  }
}
